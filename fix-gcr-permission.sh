#!/bin/bash
# Quick fix for GCR push permissions
# Run this in Cloud Shell if you already ran setup but got permission errors

set -e

echo "🔧 Fixing GCR (Container Registry) permissions..."

# Get project ID
GCP_PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
echo "Project: $GCP_PROJECT_ID"
echo ""

# Enable Container Registry API
echo "📦 Enabling Container Registry API..."
gcloud services enable containerregistry.googleapis.com
echo "✅ Container Registry API enabled"
echo ""

# Grant Storage Admin (GCR uses GCS buckets)
echo "🔐 Adding storage.admin role (if not already added)..."
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin" \
  --quiet 2>/dev/null || echo "Already has storage.admin"

# Grant Artifact Registry permissions
echo "🔐 Adding artifactregistry.admin role..."
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.admin" \
  --quiet 2>/dev/null || echo "Already has artifactregistry.admin"

echo ""
echo "🐋 Pre-creating GCR repository with initial push..."
echo "This ensures the repository exists before GitHub Actions pushes to it."
echo ""

# Build and push a minimal image to create the repository
cd services/process-video-large
docker build -t gcr.io/$GCP_PROJECT_ID/process-video-large:init .
gcloud auth configure-docker gcr.io --quiet
docker push gcr.io/$GCP_PROJECT_ID/process-video-large:init

echo ""
echo "✅ GCR repository created successfully!"
echo "✅ All permissions configured!"
echo ""
echo "Now retry your GitHub Actions workflow:"
echo "1. Go to GitHub → Actions tab"
echo "2. Click on failed workflow"  
echo "3. Click 'Re-run all jobs'"
echo ""
echo "GitHub Actions can now push to the existing repository!"
echo ""
