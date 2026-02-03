# Simplified Cloud Shell Setup (No Docker Build!)

The **fastest** way to deploy - GitHub Actions handles everything including Docker builds.

---

## Quick Setup (10 minutes)

### 1. Open Cloud Shell
- Go to [console.cloud.google.com](https://console.cloud.google.com)
- Click **Activate Cloud Shell** button (top right)

### 2. Upload Code
- Click the **⋮** menu → **Upload**
- Upload the `vutils` folder
- Or use Cloud Shell Editor to create files

### 3. Run Automated Setup

```bash
cd vutils
./setup-cloud-shell.sh
```

This script automatically:
- ✅ Enables all required GCP APIs
- ✅ Creates Firestore database
- ✅ Creates GitHub Actions service account
- ✅ Grants all necessary permissions
- ✅ Creates service account key

**⏱️ Takes ~10 minutes**

### 4. Copy Service Account Key

```bash
cat github-actions-key.json
```

Copy the entire JSON output (including `{` and `}`)

### 5. Create GitHub Repository

```bash
# Initialize git
git init
git add .
git commit -m "Initial commit"

# Create repo using GitHub CLI
gh auth login
gh repo create vutils --private --source=. --remote=origin --push
```

### 6. Add GitHub Secrets

Go to GitHub repo → **Settings** → **Secrets** → **Actions**

Add **2 secrets**:

1. **GCP_PROJECT_ID**
   ```bash
   # Get your project ID
   gcloud config get-value project
   ```
   Copy and paste as secret value

2. **GCP_SA_KEY**
   - Paste the JSON from `github-actions-key.json`

### 7. Deploy!

```bash
git push origin main
```

GitHub Actions will automatically:
1. ✅ Build Docker image for Cloud Run
2. ✅ Push to Google Container Registry
3. ✅ Run Terraform to create all infrastructure
4. ✅ Deploy Cloud Run service
5. ✅ Deploy all 3 Cloud Functions

**⏱️ Deployment takes ~15 minutes**

---

## Monitor Deployment

- Go to GitHub → **Actions** tab
- Click on running workflow
- Watch progress in real-time

---

## Verify After Deployment

```bash
# List all functions
gcloud functions list --region=asia-southeast1

# List Cloud Run services
gcloud run services list --region=asia-southeast1

# Get upload function URL
gcloud functions describe generate-upload-url \
  --region=asia-southeast1 \
  --gen2 \
  --format='value(serviceConfig.uri)'
```

---

## Test It!

```bash
FUNCTION_URL="<paste-url-from-above>"

curl -X POST $FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "fileName": "test.mp4",
    "outputFormat": "avi"
  }' | jq .
```

You'll get back:
```json
{
  "jobId": "...",
  "uploadUrl": "https://storage.googleapis.com/...",
  "expiresAt": "...",
  "maxFileSize": 1073741824
}
```

---

## Future Updates

Just edit code and push:

```bash
# Edit files
cloudshell edit functions/generate-upload-url/main.py

# Commit and push
git add .
git commit -m "Update function"
git push origin main
```

GitHub Actions automatically:
- ✅ Rebuilds Docker image (if changed)
- ✅ Redeploys updated services
- ✅ Updates Cloud Functions

---

## What GitHub Actions Does

**Every time you push to `main`:**

```yaml
1. Checkout code
2. Authenticate to GCP
3. Build Docker image               # ← No manual build needed!
4. Push to Container Registry       # ← Automatic!
5. Terraform init/plan/apply        # ← Creates all resources
6. Deploy Cloud Run service         # ← With latest image
7. Deploy Cloud Functions (×3)      # ← All functions updated
```

---

## Benefits

✅ **No Docker locally** - Build happens in cloud
✅ **No Terraform locally** - Runs in GitHub Actions
✅ **Fully automated** - Just `git push`
✅ **Consistent builds** - Same environment every time
✅ **Build logs** - See everything in Actions tab
✅ **Fast setup** - Only ~10 min in Cloud Shell

---

## Troubleshooting

**"Permission denied"**
- Check service account has all roles in setup script

**"Terraform errors"**
- View logs in GitHub Actions → Terraform Apply step

**"Function deployment failed"**
- Check Cloud Functions logs in GCP Console

**Need to rebuild manually?**
```bash
# In Cloud Shell (only if needed for testing)
cd services/process-video-large
docker build -t gcr.io/PROJECT_ID/process-video-large:latest .
docker push gcr.io/PROJECT_ID/process-video-large:latest
```

---

## Summary

**Old way:**
- Build Docker in Cloud Shell → Push manually → Then deploy

**New way (Automated):**
- Setup in Cloud Shell (10 min) → Push to GitHub → Everything else automatic!

**Total time to first deployment: ~25 minutes** 🚀
