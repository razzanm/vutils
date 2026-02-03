# Deployment Guide

## Prerequisites Checklist

- [ ] GCP Project created with billing enabled
- [ ] gcloud CLI installed (`gcloud --version`)
- [ ] Authenticated to GCP (`gcloud auth login`)
- [ ] Docker installed (for Cloud Run)
- [ ] Terraform installed (`terraform --version`)

## Step-by-Step Deployment

### 1. Set GCP Project

```bash
export GCP_PROJECT_ID="your-project-id"
gcloud config set project $GCP_PROJECT_ID
```

### 2. Enable APIs

```bash
gcloud services enable cloudfunctions.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  firestore.googleapis.com \
  storage.googleapis.com \
  appengine.googleapis.com
```

### 3. Initialize Firestore

Firestore must be created before Terraform can manage it:

```bash
# Create Firestore database (one-time setup)
gcloud firestore databases create --region=asia-southeast1
```

### 4. Create Terraform State Bucket (Optional)

```bash
gsutil mb -p $GCP_PROJECT_ID -l asia-southeast1 gs://$GCP_PROJECT_ID-terraform-state
gsutil versioning set on gs://$GCP_PROJECT_ID-terraform-state

# Then uncomment the backend config in terraform/main.tf
```

### 5. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
echo "project_id = \"$GCP_PROJECT_ID\"" > terraform.tfvars
echo "region = \"asia-southeast1\"" >> terraform.tfvars
```

### 6. Build Cloud Run Image FIRST

**IMPORTANT**: Build and push the Cloud Run image before running Terraform, as Terraform references this image.

```bash
cd ../services/process-video-large

# Build
docker build -t gcr.io/$GCP_PROJECT_ID/process-video-large:latest .

# Authenticate Docker to GCR
gcloud auth configure-docker gcr.io

# Push
docker push gcr.io/$GCP_PROJECT_ID/process-video-large:latest

cd ../../terraform
```

### 7. Deploy with Terraform

```bash
terraform init
terraform plan
terraform apply
```

This will create:
- 2 GCS buckets (uploads, outputs)
- Firestore database with indexes
- 3 Cloud Functions
- 1 Cloud Run service
- IAM service accounts and permissions

### 8. Verify Deployment

```bash
# Check Cloud Functions
gcloud functions list --region=asia-southeast1

# Check Cloud Run
gcloud run services list --region=asia-southeast1

# Check buckets
gsutil ls

# Get function URL
terraform output generate_upload_url_function_url
```

### 9. Test the System

```bash
# Get upload URL
FUNCTION_URL=$(terraform output -raw generate_upload_url_function_url)

curl -X POST $FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "fileName": "test.mp4",
    "outputFormat": "avi"
  }'

# Upload a test video using the returned signed URL
# Then monitor Firestore for progress updates
```

## GitHub Actions Setup

### 1. Create Service Account

```bash
# Create service account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Deployer"

# Grant required roles
for role in cloudfunctions.admin run.admin storage.admin datastore.user iam.serviceAccountUser cloudbuild.builds.editor; do
  gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/$role"
done

# Create and download key
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com
```

### 2. Add GitHub Secrets

In your GitHub repository settings:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add secrets:
   - `GCP_PROJECT_ID`: Your GCP project ID
   - `GCP_SA_KEY`: Contents of `github-actions-key.json`

### 3. Push to Deploy

```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

GitHub Actions will automatically deploy on push to main.

## Updating the Deployment

### Update Cloud Functions

```bash
cd functions/generate-upload-url
# Make changes to main.py
cd ../../terraform
terraform apply  # Terraform will redeploy changed functions
```

### Update Cloud Run

```bash
cd services/process-video-large
# Make changes to main.py or Dockerfile

docker build -t gcr.io/$GCP_PROJECT_ID/process-video-large:latest .
docker push gcr.io/$GCP_PROJECT_ID/process-video-large:latest

# Terraform will detect the new image on next apply
cd ../../terraform
terraform apply
```

## Troubleshooting

### Error: Firestore database already exists
If you get an error about Firestore existing, remove it from Terraform state:
```bash
terraform state rm google_firestore_database.main
terraform import google_firestore_database.main "(default)"
```

### Error: Cloud Run image not found
Build and push the Docker image before running Terraform (see Step 6).

### Permission denied errors
Ensure service accounts have all required IAM roles listed in the README.

### Function deployment timeout
Increase timeout in GitHub Actions or deploy manually:
```bash
gcloud functions deploy NAME --region=asia-southeast1 --source=. --timeout=540s
```

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

**Note**: This will delete ALL data including videos and jobs. Backup important data first.
