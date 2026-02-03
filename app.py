import os
import subprocess
import uuid
import boto3
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

def get_r2_client():
    return boto3.client(
        's3',
        endpoint_url=R2_ENDPOINT_URL,
        aws_access_key_id=R2_ACCESS_KEY_ID,
        aws_secret_access_key=R2_SECRET_ACCESS_KEY
    )

@app.route('/convert', methods=['POST'])
def convert_video():
    data = request.get_json()
    if not data or 'input_key' not in data:
        return jsonify({'error': 'Missing input_key in request body'}), 400
    
    input_key = data['input_key']
    target_format = data.get('format', 'avi')
    output_key = data.get('output_key')
    
    # Use env vars for buckets, fallback to request data if needed (optional)
    input_bucket_name = INPUT_BUCKET or data.get('input_bucket')
    output_bucket_name = OUTPUT_BUCKET or data.get('output_bucket')

    if not input_bucket_name or not output_bucket_name:
        return jsonify({'error': 'Input and Output buckets must be configured via env vars or request'}), 500

    # Local paths
    file_id = str(uuid.uuid4())
    input_filename = f"{file_id}_{os.path.basename(input_key)}"
    input_path = os.path.join(UPLOAD_FOLDER, input_filename)
    
    output_extension = f".{target_format}" if not target_format.startswith('.') else target_format
    output_filename = f"{file_id}_converted{output_extension}"
    output_path = os.path.join(UPLOAD_FOLDER, output_filename)

    # Determine final output key if not provided
    if not output_key:
        base_name = os.path.splitext(os.path.basename(input_key))[0]
        output_key = f"{base_name}{output_extension}"

    try:
        s3 = get_r2_client()
        
        # Download
        print(f"Downloading {input_key} from {input_bucket_name}...")
        s3.download_file(input_bucket_name, input_key, input_path)
        
        # Convert
        print(f"Converting {input_path} to {output_path}...")
        command = [
            'ffmpeg',
            '-y',
            '-i', input_path,
            '-q:v', '2',
            '-c:a', 'copy',
            output_path
        ]
        subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        # Upload
        print(f"Uploading {output_path} to {output_bucket_name}/{output_key}...")
        s3.upload_file(output_path, output_bucket_name, output_key)
        
        # Cleanup
        if os.path.exists(input_path):
            os.remove(input_path)
        if os.path.exists(output_path):
            os.remove(output_path)
            
        return jsonify({
            'status': 'success',
            'output_key': output_key,
            'output_bucket': output_bucket_name,
            'input_key': input_key
        })

    except subprocess.CalledProcessError as e:
        return jsonify({'error': f"Conversion failed: {str(e)}"}), 500
    except Exception as e:
        return jsonify({'error': f"An error occurred: {str(e)}"}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
