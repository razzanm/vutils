from flask import Flask, request, jsonify
import os
import tempfile
import subprocess
import re
from google.cloud import storage, firestore
from datetime import datetime, timedelta

app = Flask(__name__)

PROJECT_ID = os.environ.get('PROJECT_ID')
UPLOAD_BUCKET = os.environ.get('UPLOAD_BUCKET')
OUTPUT_BUCKET = os.environ.get('OUTPUT_BUCKET')
FIRESTORE_DATABASE = os.environ.get('FIRESTORE_DATABASE', '(default)')
PROCESSOR_TYPE = os.environ.get('PROCESSOR_TYPE', 'cloud-run')

storage_client = storage.Client()
db = firestore.Client(database=FIRESTORE_DATABASE)


def parse_ffmpeg_progress(line, total_duration):
    """Parse FFmpeg output to extract progress percentage."""
    time_match = re.search(r'time=(\d+):(\d+):(\d+\.\d+)', line)
    if time_match and total_duration > 0:
        hours, minutes, seconds = map(float, time_match.groups())
        current_time = hours * 3600 + minutes * 60 + seconds
        progress = min(int((current_time / total_duration) * 100), 99)
        return progress
    return None


def get_video_duration(file_path):
    """Get video duration in seconds using ffprobe."""
    try:
        cmd = [
            'ffprobe',
            '-v', 'error',
            '-show_entries', 'format=duration',
            '-of', 'default=noprint_wrappers=1:nokey=1',
            file_path
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return float(result.stdout.strip())
    except Exception as e:
        print(f"Error getting duration: {e}")
        return 0


def convert_video(input_path, output_path, output_format, job_ref):
    """
    Convert video using FFmpeg with optimized settings.
    Updates progress to Firestore.
    """
    try:
        # Get duration for progress tracking
        total_duration = get_video_duration(input_path)
        print(f"Video duration: {total_duration}s")
        
        # Build FFmpeg command based on output format
        # Strategy: Copy audio where possible, use fast encoding
        cmd = ['ffmpeg', '-i', input_path, '-y']
        
        # Format-specific encoding
        if output_format.lower() in ['mp4', 'm4v']:
            cmd.extend(['-c:v', 'libx264', '-preset', 'ultrafast', '-c:a', 'copy'])
        elif output_format.lower() == 'avi':
            cmd.extend(['-c:v', 'mpeg4', '-q:v', '5', '-c:a', 'copy'])
        elif output_format.lower() in ['mkv', 'webm']:
            cmd.extend(['-c', 'copy'])  # Try to copy both streams
        elif output_format.lower() == 'mov':
            cmd.extend(['-c:v', 'libx264', '-preset', 'ultrafast', '-c:a', 'copy'])
        else:
            # Default: fast encoding, try audio copy
            cmd.extend(['-c:v', 'libx264', '-preset', 'ultrafast', '-c:a', 'copy'])
        
        cmd.append(output_path)
        
        print(f"FFmpeg command: {' '.join(cmd)}")
        
        # Run FFmpeg with progress tracking
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True
        )
        
        last_progress = 0
        for line in process.stdout:
            print(line.strip())
            
            progress = parse_ffmpeg_progress(line, total_duration)
            if progress and progress != last_progress and progress % 10 == 0:
                # Update every 10%
                job_ref.update({
                    'progress.percent': progress,
                    'progress.currentStep': 'Converting video',
                    'updatedAt': firestore.SERVER_TIMESTAMP
                })
                print(f"Progress: {progress}%")
                last_progress = progress
        
        process.wait()
        
        if process.returncode != 0:
            raise Exception(f"FFmpeg failed with code {process.returncode}")
        
        print("Conversion completed successfully")
        return True
        
    except Exception as e:
        print(f"Conversion error: {e}")
        raise


@app.route('/', methods=['POST'])
def process_video():
    """
    Processes large video files.
    Receives job details, downloads, converts, and uploads result.
    """
    job_id = None
    temp_input = None
    temp_output = None
    
    try:
        request_json = request.get_json()
        if not request_json:
            return jsonify({'error': 'Request body must be JSON'}), 400
        
        job_id = request_json['jobId']
        bucket_name = request_json['bucketName']
        file_path = request_json['filePath']
        
        print(f"Processing job {job_id}: {file_path}")
        
        # Get job details from Firestore
        job_ref = db.collection('conversion-jobs').document(job_id)
        job = job_ref.get()
        if not job.exists:
            return jsonify({'error': f'Job {job_id} not found'}), 404
        
        job_data = job.to_dict()
        output_format = job_data.get('outputFile', {}).get('format', 'mp4')
        
        # Update status to PROCESSING
        job_ref.update({
            'status': 'PROCESSING',
            'claimedAt': firestore.SERVER_TIMESTAMP,
            'claimedBy': f'{PROCESSOR_TYPE}-instance',
            'progress.percent': 0,
            'progress.currentStep': 'Downloading video',
            'updatedAt': firestore.SERVER_TIMESTAMP
        })
        
        # Download input file
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(file_path)
        
        temp_input = tempfile.NamedTemporaryFile(delete=False, suffix='.input')
        blob.download_to_filename(temp_input.name)
        print(f"Downloaded to {temp_input.name}")
        
        # Update progress
        job_ref.update({
            'progress.percent': 10,
            'progress.currentStep': 'Starting conversion',
            'updatedAt': firestore.SERVER_TIMESTAMP
        })
        
        # Convert video
        temp_output = tempfile.NamedTemporaryFile(delete=False, suffix=f'.{output_format}')
        convert_video(temp_input.name, temp_output.name, output_format, job_ref)
        
        # Upload output
        job_ref.update({
            'progress.percent': 95,
            'progress.currentStep': 'Uploading result',
            'updatedAt': firestore.SERVER_TIMESTAMP
        })
        
        original_name = os.path.basename(file_path)
        name_without_ext = os.path.splitext(original_name)[0]
        output_path = f"outputs/{job_id}/{name_without_ext}.{output_format}"
        
        output_bucket = storage_client.bucket(OUTPUT_BUCKET)
        output_blob = output_bucket.blob(output_path)
        output_blob.upload_from_filename(temp_output.name, content_type=f'video/{output_format}')
        
        # Generate signed URL for download (valid for 7 days)
        expires_at = datetime.utcnow() + timedelta(days=7)
        signed_url = output_blob.generate_signed_url(
            version='v4',
            expiration=expires_at,
            method='GET'
        )
        
        # Mark complete
        job_ref.update({
            'status': 'COMPLETED',
            'progress.percent': 100,
            'progress.currentStep': 'Done',
            'outputFile.bucket': OUTPUT_BUCKET,
            'outputFile.path': output_path,
            'outputFile.signedUrl': signed_url,
            'outputFile.urlExpiresAt': expires_at,
            'completedAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP
        })
        
        print(f"Job {job_id} completed successfully")
        
        return jsonify({'status': 'success', 'jobId': job_id}), 200
        
    except Exception as e:
        print(f"Error processing job: {e}")
        import traceback
        traceback.print_exc()
        
        if job_id:
            try:
                job_ref = db.collection('conversion-jobs').document(job_id)
                job_ref.update({
                    'status': 'FAILED',
                    'error': {
                        'code': 'PROCESSING_ERROR',
                        'message': str(e)
                    },
                    'updatedAt': firestore.SERVER_TIMESTAMP
                })
            except:
                pass
        
        return jsonify({'error': str(e)}), 500
        
    finally:
        # Cleanup temp files
        if temp_input and os.path.exists(temp_input.name):
            os.unlink(temp_input.name)
        if temp_output and os.path.exists(temp_output.name):
            os.unlink(temp_output.name)


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({'status': 'healthy'}), 200


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
