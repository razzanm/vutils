import os
import subprocess
import uuid
import boto3
import requests
import traceback
from flask import Flask, request, jsonify

app = Flask(__name__)

# Configuration
UPLOAD_FOLDER = '/tmp/vutils_uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

R2_ENDPOINT_URL = os.environ.get('R2_ENDPOINT_URL')
R2_ACCESS_KEY_ID = os.environ.get('R2_ACCESS_KEY_ID')
R2_SECRET_ACCESS_KEY = os.environ.get('R2_SECRET_ACCESS_KEY')
INPUT_BUCKET = os.environ.get('INPUT_BUCKET')
OUTPUT_BUCKET = os.environ.get('OUTPUT_BUCKET')
STATUS_API_BASE_URL = "https://converter-status.rajan-1si18cs083.workers.dev"

def get_r2_client():
    return boto3.client(
        's3',
        endpoint_url=R2_ENDPOINT_URL,
        aws_access_key_id=R2_ACCESS_KEY_ID,
        aws_secret_access_key=R2_SECRET_ACCESS_KEY
    )

def update_job_status(job_id, status, progress=None, message=None, output_key=None):
    """Updates the job status via the Status API."""
    url = f"{STATUS_API_BASE_URL}/update"
    payload = {
        "jobId": job_id,
        "status": status
    }
    if progress is not None:
        payload["progress"] = progress
    if message:
        payload["message"] = message
    if output_key:
        payload["outputKey"] = output_key
    
    try:
        response = requests.post(url, json=payload, timeout=10)
        response.raise_for_status()
        print(f"Status updated for {job_id}: {status}")
    except Exception as e:
        print(f"Failed to update status for {job_id}: {e}")

def get_job_details(job_id):
    """Fetches job details to get the input filename."""
    url = f"{STATUS_API_BASE_URL}/status/{job_id}"
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    return response.json()

@app.route('/convert', methods=['POST'])
def convert_video():
    data = request.get_json()
    if not data or 'jobId' not in data:
        return jsonify({'error': 'Missing jobId in request body'}), 400
    
    job_id = data['jobId']
    target_format = data.get('format', 'mp4')
    # options = data.get('options', {}) # Reserved for future use

    print(f"Received job {job_id} for format {target_format}")

    # 1. Start Processing
    update_job_status(job_id, "processing", 0, "Processing started...")

    file_id = str(uuid.uuid4())
    input_path = None
    output_path = None

    try:
        # Check if buckets are configured
        if not INPUT_BUCKET or not OUTPUT_BUCKET:
            raise ValueError("INPUT_BUCKET and OUTPUT_BUCKET must be set in environment variables.")

        # 2. Fetch Metadata
        print(f"Fetching metadata for job {job_id}...")
        job_metadata = get_job_details(job_id)
        input_key = job_metadata.get('fileName')
        
        if not input_key:
            raise ValueError("fileName not found in job metadata")

        # Setup paths
        input_filename = f"{file_id}_{os.path.basename(input_key)}"
        input_path = os.path.join(UPLOAD_FOLDER, input_filename)
        
        output_extension = f".{target_format}" if not target_format.startswith('.') else target_format
        output_filename = f"{file_id}_converted{output_extension}"
        output_path = os.path.join(UPLOAD_FOLDER, output_filename)
        
        # Consistent naming convention for output
        final_output_key = f"processed-{job_id}{output_extension}"

        s3 = get_r2_client()

        # 3. Download Input
        print(f"Downloading {input_key} from {INPUT_BUCKET}...")
        s3.download_file(INPUT_BUCKET, input_key, input_path)

        # 4. Progress Updates
        update_job_status(job_id, "processing", 10)

        # 5. Convert
        print(f"Converting {input_path} to {output_path}...")
        # Basic ffmpeg command that should work for most format conversions
        command = [
            'ffmpeg',
            '-y',
            '-i', input_path,
            output_path
        ]
        
        update_job_status(job_id, "processing", 20, "Encoding video...")
        
        subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        update_job_status(job_id, "processing", 90, "Uploading...")

        # 6. Job Completion -> Upload
        print(f"Uploading {output_path} to {OUTPUT_BUCKET}/{final_output_key}...")
        s3.upload_file(output_path, OUTPUT_BUCKET, final_output_key)

        # 7. Final Success Update
        update_job_status(
            job_id, 
            "completed", 
            100, 
            "Conversion successful", 
            output_key=final_output_key
        )
        
        return jsonify({
            'status': 'success',
            'jobId': job_id,
            'outputKey': final_output_key
        })

    except Exception as e:
        error_msg = str(e)
        print(f"Job {job_id} failed: {error_msg}")
        traceback.print_exc()
        update_job_status(job_id, "failed", message=error_msg)
        return jsonify({'error': error_msg}), 500
    
    finally:
        # Cleanup
        if input_path and os.path.exists(input_path):
            try:
                os.remove(input_path)
            except:
                pass
        if output_path and os.path.exists(output_path):
            try:
                os.remove(output_path)
            except:
                pass

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
