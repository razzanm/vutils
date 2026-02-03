# Cloud Shell + GitHub Actions Deployment

**Fastest way to deploy**: Use GCP Cloud Shell for setup, GitHub Actions for automated deployment.

---

## Step 1: Open Cloud Shell

1. Go to [GCP Console](https://console.cloud.google.com)
2. Click **Activate Cloud Shell** button (top right)
3. Wait for shell to initialize

---

## Step 2: Clone Your Code to Cloud Shell

```bash
# Upload your code or clone from GitHub
# Option A: If not yet on GitHub, upload the vutils folder using Cloud Shell upload button

# Option B: If already on GitHub
git clone https://github.com/YOUR_USERNAME/vutils.git
cd vutils

# Option C: Create from scratch - copy files from local machine
# Use Cloud Shell's built-in file editor or upload feature
```

---

## Step 3: Set Your Project

```bash
# List available projects
gcloud projects list

# Set your project (replace with your project ID)
export GCP_PROJECT_ID="your-project-id"
gcloud config set project $GCP_PROJECT_ID

# Verify
echo "Using project: $GCP_PROJECT_ID"
```

---

## Step 4: Enable APIs (2 minutes)

```bash
gcloud services enable \
  cloudfunctions.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  firestore.googleapis.com \
  storage.googleapis.com \
  appengine.googleapis.com \
  containerregistry.googleapis.com
```

---

## Step 5: Initialize Firestore (1 minute)

```bash
gcloud firestore databases create --region=asia-southeast1
```

If already exists, that's fine - skip to next step.

---

## Step 6: Create GitHub Actions Service Account (2 minutes)

```bash
# Create service account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Deployer"

# Grant all requi# Grant permissions
for role in cloudfunctions.admin run.admin storage.admin datastore.user \
  iam.serviceAccountUser cloudbuild.builds.editor serviceusage.services.use; do
  gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/$role"
done

# Create and download key
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com

echo "✅ Service account created with key saved to github-actions-key.json"
```

---

## Step 7: Push Code to GitHub (5 minutes)

> **Note**: Docker image building is now fully automated in GitHub Actions - no manual build needed!

### 7.1 Initialize Git (if not already done)

```bash
git init
git add .
git commit -m "Initial commit: Video converter backend"
```

### 7.2 Create GitHub Repository

**Option A: Using GitHub CLI in Cloud Shell**
```bash
# Authenticate to GitHub
gh auth login
# Follow prompts to authenticate

# Create repo and push
gh repo create vutils --private --source=. --remote=origin --push
```

**Option B: Create on GitHub.com**
```bash
# 1. Go to https://github.com/new
# 2. Create repository named "vutils"
# 3. Then run:

git remote add origin https://github.com/YOUR_USERNAME/vutils.git
git branch -M main
git push -u origin main
```

---

## Step 8: Configure GitHub Secrets (2 minutes)

### 8.1 Get Service Account Key Content

```bash
# Display the key (copy this output)
cat github-actions-key.json
```

Select and copy the entire JSON output (including `{` and `}`)

### 8.2 Add Secrets to GitHub

1. Go to your GitHub repository
2. **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

**Secret 1: GCP_PROJECT_ID**
- Name: `GCP_PROJECT_ID`
- Value: Your project ID (run `echo $GCP_PROJECT_ID` to see it)

**Secret 2: GCP_SA_KEY**
- Name: `GCP_SA_KEY`  
- Value: Paste the entire JSON from `cat github-actions-key.json`

---

## Step 9: Deploy via GitHub Actions (1 minute)

```bash
# Trigger deployment by pushing to main
git push origin main
```

**Monitor deployment**:
1. Go to your GitHub repository
2. Click **Actions** tab
3. Watch the workflow run (~10-15 minutes)

The workflow will automatically:
- ✅ Build and push Docker image to GCR
- ✅ Run Terraform to create infrastructure  
- ✅ Deploy Cloud Run service with latest image
- ✅ Deploy all 3 Cloud Functions

---

## Step 10: Verify Deployment (1 minute)

Back in Cloud Shell:

```bash
# Check Cloud Functions
gcloud functions list --region=asia-southeast1

# Check Cloud Run
gcloud run services list --region=asia-southeast1

# Get upload function URL
gcloud functions describe generate-upload-url \
  --region=asia-southeast1 \
  --gen2 \
  --format='value(serviceConfig.uri)'
```

---

## Step 11: Test the System (2 minutes)

```bash
# Set the function URL (from previous command)
FUNCTION_URL="https://asia-southeast1-PROJECT_ID.cloudfunctions.net/generate-upload-url"

# Generate upload URL
curl -X POST $FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "fileName": "test.mp4",
    "outputFormat": "avi"
  }' | jq .

# You'll get back jobId and uploadUrl
# Upload a video to test:
# curl -X PUT "SIGNED_URL" --upload-file video.mp4 -H "Content-Type: video/mp4"
```

---

## Future Updates

### Make Code Changes in Cloud Shell

```bash
# Edit files using Cloud Shell Editor
cloudshell edit functions/generate-upload-url/main.py

# Or use vim/nano
vim functions/generate-upload-url/main.py

# Commit and push
git add .
git commit -m "Update function"
git push origin main
```

GitHub Actions automatically deploys! 🚀

---

## Cleanup

### Delete Everything

```bash
# Install Terraform in Cloud Shell if needed
wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
unzip terraform_1.5.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Destroy resources
cd terraform
terraform init
terraform destroy
```

---

## Quick Commands Reference

```bash
# View logs
gcloud functions logs read FUNCTION_NAME --region=asia-southeast1 --limit=20
gcloud run logs read process-video-large --region=asia-southeast1 --limit=20

# List resources
gcloud functions list --region=asia-southeast1
gcloud run services list --region=asia-southeast1
gsutil ls

# Redeploy
git push origin main
```

---

## Advantages of Cloud Shell

✅ No local setup needed
✅ gcloud already authenticated
✅ Docker pre-installed
✅ Built-in code editor
✅ Free to use
✅ Persistent storage (5GB)
✅ Can close browser - work persists

---

## Total Time

- **Cloud Shell Setup**: ~10 minutes (no Docker build needed!)
- **GitHub Actions Deployment**: ~15 minutes (builds Docker + deploys)
- **Total**: ~25 minutes from zero to deployed!

**Next deployment**: Just `git push` - takes 10-15 min automatically 🎉
