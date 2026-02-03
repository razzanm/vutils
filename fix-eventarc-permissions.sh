#!/bin/bash
# Grant Eventarc Service Account Permissions
# Run this in Cloud Shell to fix the trigger-conversion function deployment

set -e

GCP_PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
echo "🔧 Granting Eventarc service account permissions..."
echo "Project: $GCP_PROJECT_ID"
echo ""

# Get project number
PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT_ID --format="value(projectNumber)")
EVENTARC_SA="service-${PROJECT_NUMBER}@gcp-sa-eventarc.iam.gserviceaccount.com"

echo "Eventarc Service Account: $EVENTARC_SA"
echo ""

# Grant permissions on upload bucket for event triggers
echo "Granting permissions on ${GCP_PROJECT_ID}-uploads bucket..."
gsutil iam ch serviceAccount:${EVENTARC_SA}:objectViewer gs://${GCP_PROJECT_ID}-uploads
gsutil iam ch serviceAccount:${EVENTARC_SA}:legacyBucketReader gs://${GCP_PROJECT_ID}-uploads

echo ""
echo "✅ Eventarc permissions granted!"
echo ""
echo "Now retry your GitHub Actions workflow:"
echo "1. Go to GitHub → Actions tab"
echo "2. Click on failed workflow"
echo "3. Click 'Re-run failed jobs'"
echo ""
