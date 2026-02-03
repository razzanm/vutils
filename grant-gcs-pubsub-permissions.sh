#!/bin/bash
# Grant GCS Service Account Pub/Sub Permissions
# Run this ONCE in Cloud Shell before deploying trigger-conversion function

set -e

GCP_PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
echo "🔧 Granting GCS service account Pub/Sub permissions..."
echo "Project: $GCP_PROJECT_ID"
echo ""

# Get project number
PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT_ID --format="value(projectNumber)")
GCS_SA="service-${PROJECT_NUMBER}@gs-project-accounts.iam.gserviceaccount.com"

echo "GCS Service Account: $GCS_SA"
echo ""

# Grant Pub/Sub Publisher role for Eventarc triggers
echo "Granting Pub/Sub Publisher role..."
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:${GCS_SA}" \
  --role="roles/pubsub.publisher"

echo ""
echo "✅ GCS service account permissions granted!"
echo ""
echo "Now retry your GitHub Actions workflow:"
echo "1. Go to GitHub → Actions tab"
echo "2. Click on failed workflow"
echo "3. Click 'Re-run failed jobs'"
echo ""
echo "The trigger-conversion function will now deploy successfully!"
echo ""
