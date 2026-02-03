# Quick Start: GitHub Actions Deployment

Follow these steps in order to deploy via GitHub Actions.

## Prerequisites Checklist
- [ ] GCP Project created
- [ ] gcloud CLI installed
- [ ] Docker installed
- [ ] GitHub account

---

## 1. GCP Setup (5 minutes)

```bash
# Set your project
export GCP_PROJECT_ID="your-project-id"
gcloud config set project $GCP_PROJECT_ID

# Enable APIs
gcloud services enable cloudfunctions.googleapis.com run.googleapis.com \
  cloudbuild.googleapis.com firestore.googleapis.com storage.googleapis.com \
  appengine.googleapis.com containerregistry.googleapis.com

# Create Firestore database
gcloud firestore databases create --region=asia-southeast1
```

---

## 2. Create GitHub Actions Service Account (3 minutes)

```bash
# Create service account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Deployer"

# Grant permissions
for role in cloudfunctions.admin run.admin storage.admin datastore.user \
  iam.serviceAccountUser cloudbuild.builds.editor resourcemanager.projects.get \
  serviceusage.services.use; do
  gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/$role"
done

# Create key
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=github-actions@$GCP_PROJECT_ID.iam.gserviceaccount.com
```

**⚠️ IMPORTANT**: Keep `github-actions-key.json` secure!

---

## 3. Push Initial Docker Image (2 minutes)

```bash
cd services/process-video-large

# Build
docker build -t gcr.io/$GCP_PROJECT_ID/process-video-large:latest .

# Authenticate & Push
gcloud auth configure-docker gcr.io
docker push gcr.io/$GCP_PROJECT_ID/process-video-large:latest
```

---

## 4. Create GitHub Repository (2 minutes)

```bash
cd /Users/rajan/Desktop/Projects/vutils

git init
git add .
git commit -m "Initial commit"

# Option A: GitHub CLI
gh repo create vutils --private --source=. --remote=origin --push

# Option B: Create on GitHub.com, then:
git remote add origin https://github.com/YOUR_USERNAME/vutils.git
git branch -M main
git push -u origin main
```

---

## 5. Configure GitHub Secrets (2 minutes)

Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions**

**Add two secrets**:

1. **GCP_PROJECT_ID**
   - Value: `your-project-id`

2. **GCP_SA_KEY**
   - Copy key content:
     ```bash
     cat github-actions-key.json | pbcopy  # macOS
     # or
     cat github-actions-key.json  # copy manually
     ```
   - Paste entire JSON as secret value

---

## 6. Deploy! (1 minute)

```bash
# Push to trigger deployment
git push origin main
```

**Monitor deployment**:
- Go to GitHub → **Actions** tab
- Watch the workflow run (~10-15 minutes)

---

## 7. Verify (2 minutes)

```bash
# Check functions
gcloud functions list --region=asia-southeast1

# Check Cloud Run
gcloud run services list --region=asia-southeast1

# Get function URL
gcloud functions describe generate-upload-url \
  --region=asia-southeast1 \
  --gen2 \
  --format='value(serviceConfig.uri)'
```

---

## 8. Test (1 minute)

```bash
FUNCTION_URL="<paste-url-from-above>"

curl -X POST $FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{"fileName": "test.mp4", "outputFormat": "avi"}' | jq .
```

---

## Done! 🎉

**Total time**: ~15 minutes for setup + ~15 minutes for deployment

**Next time**: Just `git push origin main` to deploy updates!

---

## Troubleshooting

**"Permission denied"**: Check service account has all roles
**"Docker image not found"**: Rebuild and push Docker image first
**"Terraform errors"**: Check logs in GitHub Actions tab

Full guide: [github_deployment.md](file:///Users/rajan/.gemini/antigravity/brain/3a2fbefc-c675-438f-97db-6e9f64558c6f/github_deployment.md)
