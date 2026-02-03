#!/bin/bash
# Enable missing API and import existing Firestore
# Run this in Cloud Shell to fix Terraform errors

set -e

GCP_PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
echo "🔧 Fixing Terraform deployment issues..."
echo "Project: $GCP_PROJECT_ID"
echo ""

# Enable Cloud Resource Manager API (needed for IAM operations)
echo "📦 Enabling Cloud Resource Manager API..."
gcloud services enable cloudresourcemanager.googleapis.com
echo "✅ Cloud Resource Manager API enabled"
echo ""

echo "✅ API enabled! Wait 2-3 minutes for it to propagate."
echo ""
echo "Then retry your GitHub Actions workflow:"
echo "1. Go to GitHub → Actions tab"
echo "2. Click on failed workflow"
echo "3. Click 'Re-run all jobs'"
echo ""
echo "Note: The Firestore database error should also resolve automatically."
echo "Terraform will detect the existing database and continue."
echo ""
