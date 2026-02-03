import functions_framework
import os
import uuid
from datetime import datetime, timedelta
from google.cloud import storage, firestore
import json

PROJECT_ID = os.environ.get('PROJECT_ID')
UPLOAD_BUCKET = os.environ.get('UPLOAD_BUCKET')
MAX_FILE_SIZE_MB = int(os.environ.get('MAX_FILE_SIZE_MB', 1024))
FIRESTORE_DATABASE = os.environ.get('FIRESTORE_DATABASE', '(default)')

storage_client = storage.Client()
db = firestore.Client(database=FIRESTORE_DATABASE)


@functions_framework.http
def generate_upload_url(request):
    """
    HTTP Cloud Function to generate signed upload URL.
    
    Request JSON:
    {
        "fileName": "video.mp4",
        "outputFormat": "avi",
        "settings": {"quality": "medium"}
    }
    
    Response:
    {
        "jobId": "uuid",
        "uploadUrl": "https://...",
        "expiresAt": "ISO timestamp",
        "maxFileSize": 1073741824
    }
    """
    # CORS headers
    if request.method == 'OPTIONS':
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Max-Age': '3600'
        }
        return ('', 204, headers)
    
    headers = {
        'Access-Control-Allow-Origin': '*'
    }
    
    try:
        request_json = request.get_json(silent=True)
        if not request_json:
            return (json.dumps({'error': 'Request body must be JSON'}), 400, headers)
        
        file_name = request_json.get('fileName', 'video.mp4')
        output_format = request_json.get('outputFormat', 'mp4')
        settings = request_json.get('settings', {})
        
        # Generate job ID
        job_id = str(uuid.uuid4())
        
        # Generate unique upload path
        upload_path = f"uploads/{job_id}/{file_name}"
        
        # Create Firestore job document
        job_data = {
            'jobId': job_id,
            'status': 'PENDING',
            'inputFile': {
                'bucket': UPLOAD_BUCKET,
                'path': upload_path,
                'originalName': file_name
            },
            'outputFile': {
                'format': output_format
            },
            'conversionSettings': settings,
            'progress': {
                'percent': 0
            },
            'createdAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP
        }
        
        db.collection('conversion-jobs').document(job_id).set(job_data)
        
        # Generate signed URL (15 minutes expiration)
        bucket = storage_client.bucket(UPLOAD_BUCKET)
        blob = bucket.blob(upload_path)
        
        expires_at = datetime.utcnow() + timedelta(minutes=15)
        
        upload_url = blob.generate_signed_url(
            version='v4',
            expiration=expires_at,
            method='PUT',
            content_type='video/*'
        )
        
        response = {
            'jobId': job_id,
            'uploadUrl': upload_url,
            'expiresAt': expires_at.isoformat() + 'Z',
            'maxFileSize': MAX_FILE_SIZE_MB * 1024 * 1024
        }
        
        return (json.dumps(response), 200, headers)
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return (json.dumps({'error': str(e)}), 500, headers)
