import functions_framework
import os
import requests
from google.cloud import storage, firestore
from cloudevents.http import CloudEvent

PROJECT_ID = os.environ.get('PROJECT_ID')
UPLOAD_BUCKET = os.environ.get('UPLOAD_BUCKET')
SMALL_FILE_THRESHOLD_MB = int(os.environ.get('SMALL_FILE_THRESHOLD_MB', 100))
SMALL_PROCESSOR_URL = os.environ.get('SMALL_PROCESSOR_URL')
LARGE_PROCESSOR_URL = os.environ.get('LARGE_PROCESSOR_URL')
FIRESTORE_DATABASE = os.environ.get('FIRESTORE_DATABASE', '(default)')

storage_client = storage.Client()
db = firestore.Client(database=FIRESTORE_DATABASE)


@functions_framework.cloud_event
def trigger_conversion(cloud_event: CloudEvent):
    """
    Triggered when a file is uploaded to GCS.
    Determines file size and delegates to appropriate processor.
    """
    try:
        data = cloud_event.data
        
        bucket_name = data["bucket"]
        file_path = data["name"]
        
        print(f"File uploaded: gs://{bucket_name}/{file_path}")
        
        # Extract job ID from path (format: uploads/{jobId}/filename)
        path_parts = file_path.split('/')
        if len(path_parts) < 2 or path_parts[0] != 'uploads':
            print(f"Skipping file with invalid path format: {file_path}")
            return
        
        job_id = path_parts[1]
        
        # Get file metadata
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(file_path)
        blob.reload()
        
        file_size = blob.size
        file_size_mb = file_size / (1024 * 1024)
        
        # Determine processor based on file size
        if file_size_mb < SMALL_FILE_THRESHOLD_MB:
            processor = 'cloud-function'
            processor_url = SMALL_PROCESSOR_URL
        else:
            processor = 'cloud-run'
            processor_url = LARGE_PROCESSOR_URL
        
        print(f"Job {job_id}: {file_size_mb:.2f}MB -> {processor}")
        
        # Update Firestore job
        job_ref = db.collection('conversion-jobs').document(job_id)
        job_ref.update({
            'status': 'QUEUED',
            'processor': processor,
            'inputFile.size': file_size,
            'inputFile.path': file_path,
            'updatedAt': firestore.SERVER_TIMESTAMP
        })
        
        # Delegate to appropriate processor
        payload = {
            'jobId': job_id,
            'bucketName': bucket_name,
            'filePath': file_path,
            'fileSize': file_size
        }
        
        # Get service account token for authenticated requests
        import google.auth
        import google.auth.transport.requests
        
        credentials, project = google.auth.default()
        auth_req = google.auth.transport.requests.Request()
        credentials.refresh(auth_req)
        
        headers = {
            'Authorization': f'Bearer {credentials.token}',
            'Content-Type': 'application/json'
        }
        
        response = requests.post(processor_url, json=payload, headers=headers, timeout=60)
        
        if response.status_code != 200:
            print(f"Error invoking processor: {response.status_code} {response.text}")
            job_ref.update({
                'status': 'FAILED',
                'error': {
                    'code': 'PROCESSOR_INVOCATION_FAILED',
                    'message': f'Failed to invoke processor: {response.status_code}'
                },
                'updatedAt': firestore.SERVER_TIMESTAMP
            })
        else:
            print(f"Successfully delegated job {job_id} to {processor}")
        
    except Exception as e:
        print(f"Error in trigger_conversion: {str(e)}")
        import traceback
        traceback.print_exc()
