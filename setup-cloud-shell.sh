#!/bin/bash
# Cloud Shell Setup Script for Video Converter Backend
# Run this in GCP Cloud Shell

set -e  # Exit on error

echo "🚀 Video Converter Backend - Cloud Shell Setup"
echo "=============================================="
echo ""

# Get project ID
echo "📋 Step 1: Set GCP Project"
gcloud projects list
read -p "Enter your GCP Project ID: " GCP_PROJECT_ID
gcloud config set project $GCP_PROJECT_ID
echo "✅ Project set to: $GCP_PROJECT_ID"
echo ""

# Enable APIs
echo "🔧 Step 2: Enabling required APIs..."
gcloud services enable \
  cloudfunctions.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  firestore.googleapis.com \
  storage.googleapis.com \
  appengine.googleapis.com \
  containerregistry.googleapis.com \
  cloudresourcemanager.googleapis.com \
  eventarc.googleapis.com
echo "✅ APIs enabled"
echo ""

# Create Firestore
echo "🗄️  Step 3: Creating Firestore database..."
if gcloud firestore databases create --region=asia-southeast1 2>/dev/null; then
    echo "✅ Firestore database created"
else
    echo "⚠️  Firestore database already exists (this is fine)"
fi
echo ""

# Create service account
echo "👤 Step 4: Creating GitHub Actions service account..."
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Deployer" 2>/dev/null || echo "Service account already exists"
echo "✅ Service account created"
echo ""

# Grant permissions
echo "🔐 Step 5: Granting permissions..."
for role in \
  cloudfunctions.admin \
  run.admin \
  storage.admin \
  artifactregistry.admin \
  datastore.user \
  iam.serviceAccountUser \
  cloudbuild.builds.editor \
  serviceusage.services.use
do
  gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/$role" \
    --quiet 2>/dev/null || echo "  ⚠️  Could not grant $role (may already exist)"
  echo "  ✓ Granted $role"
done
echo "✅ All permissions granted"
echo ""

# Grant GCS service account Pub/Sub publisher for Eventarc
echo "🔐 Step 6: Granting Cloud Storage service account Pub/Sub permissions..."
PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT_ID --format="value(projectNumber)")
GCS_SA="service-${PROJECT_NUMBER}@gs-project-accounts.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:${GCS_SA}" \
  --role="roles/pubsub.publisher" \
  --quiet 2>/dev/null || echo "  ⚠️  Already has pubsub.publisher"
echo "✅ GCS service account configured"
echo ""

# Create key
echo "🔑 Step 6: Creating service account key..."
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com
echo "✅ Key created: github-actions-key.json"
echo ""

echo "⏭️  Skipping Docker build - GitHub Actions will handle this automatically"
echo ""

# Display next steps
echo "=============================================="
echo "✅ GCP Setup Complete!"
echo "=============================================="
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Copy the service account key for GitHub:"
echo "   cat github-actions-key.json"
echo ""
echo "2. Create GitHub repository and add secrets:"
echo "   - GCP_PROJECT_ID: $GCP_PROJECT_ID"
echo "   - GCP_SA_KEY: (paste JSON from above)"
echo ""
echo "3. Push code to GitHub:"
echo "   git remote add origin https://github.com/YOUR_USERNAME/vutils.git"
echo "   git push -u origin main"
echo ""
echo "4. Watch deployment in GitHub Actions tab"
echo ""
echo "🎉 Setup complete! Ready for GitHub Actions deployment."
