# Video Converter Backend - GCP Deployment

A scalable video conversion service built on Google Cloud Platform with smart resource allocation based on file size.

## Architecture

- **Region**: asia-southeast1
- **Small Files (<100MB)**: Cloud Function Gen 2 (4 vCPU, 8GB RAM)
- **Large Files (≥100MB)**: Cloud Run (8 vCPU, 16GB RAM)
- **Storage**: GCS with 8-hour lifecycle
- **Database**: Firestore for job tracking
- **Max File Size**: 1GB

## Prerequisites

1. **GCP Project** with billing enabled
2. **gcloud CLI** installed and configured
3. **Terraform** >= 1.5.0
4. **Docker** (for local Cloud Run testing)

## Setup Instructions

### 1. Enable Required APIs

```bash
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable firestore.googleapis.com
gcloud services enable storage.googleapis.com
```

### 2. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set your project_id
```

### 3. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Build and Deploy Cloud Run

```bash
# Build Docker image
cd services/process-video-large
docker build -t gcr.io/YOUR_PROJECT_ID/process-video-large:latest .

# Push to GCR
docker push gcr.io/YOUR_PROJECT_ID/process-video-large:latest

# Deploy (or use GitHub Actions)
gcloud run deploy process-video-large \
  --image gcr.io/YOUR_PROJECT_ID/process-video-large:latest \
  --region asia-southeast1 \
  --cpu 8 \
  --memory 16Gi \
  --timeout 3600 \
  --max-instances 100 \
  --min-instances 0
```

## GitHub Actions CI/CD

### Required Secrets

Add these secrets to your GitHub repository:

- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_SA_KEY`: Service account JSON key with required permissions

### Service Account Permissions

The service account needs:
- Cloud Functions Admin
- Cloud Run Admin
- Storage Admin
- Firestore User
- Service Account User
- Cloud Build Editor

### Auto-Deployment

Push to `main` branch triggers automatic deployment to GCP.

## API Usage

### 1. Generate Upload URL

```bash
curl -X POST https://REGION-PROJECT_ID.cloudfunctions.net/generate-upload-url \
  -H "Content-Type: application/json" \
  -d '{
    "fileName": "video.mp4",
    "outputFormat": "avi",
    "settings": {}
  }'
```

Response:
```json
{
  "jobId": "uuid",
  "uploadUrl": "https://storage.googleapis.com/...",
  "expiresAt": "2026-02-03T10:45:00Z",
  "maxFileSize": 1073741824
}
```

### 2. Upload Video

```bash
curl -X PUT "SIGNED_URL_FROM_STEP_1" \
  --upload-file video.mp4 \
  -H "Content-Type: video/mp4"
```

### 3. Monitor Progress (Firestore)

Listen to Firestore document updates for real-time progress:

```javascript
const db = firebase.firestore();
db.collection('conversion-jobs').doc(jobId)
  .onSnapshot(doc => {
    const job = doc.data();
    console.log(job.status, job.progress);
    if (job.status === 'COMPLETED') {
      console.log('Download:', job.outputFile.signedUrl);
    }
  });
```

## Supported Formats

- **Input**: All video formats supported by FFmpeg
- **Output**: MP4, AVI, MOV, MKV, WebM, FLV, WMV, and more

## Cost Optimization

- Min instances set to 0 (scale to zero when idle)
- Smart delegation reduces costs by 40-60% for small files
- 8-hour file lifecycle prevents storage buildup
- No unnecessary transcoding (audio copy when possible)

## Monitoring

View logs in GCP Console:
- **Cloud Functions**: Cloud Functions > Logs
- **Cloud Run**: Cloud Run > Logs
- **Firestore**: Firestore > Data

## Cleanup

```bash
cd terraform
terraform destroy
```

## Troubleshooting

### FFmpeg not found in Cloud Function
Cloud Functions Gen 2 doesn't include FFmpeg by default. It's included in the Cloud Run service via Dockerfile.

### File upload fails
- Check signed URL hasn't expired (15-minute limit)
- Verify file size is under 1GB
- Ensure correct Content-Type header

### Job stuck in PROCESSING
- Check Cloud Run/Function logs for errors
- Verify service accounts have proper permissions
- Check Firestore rules allow writes

## License

MIT
