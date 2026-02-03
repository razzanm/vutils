# Cloud Shell Authentication & API Fix

Run these commands in **Cloud Shell** to fix authentication and enable the required API:

## Step 1: List Available Accounts
```bash
gcloud auth list
```

## Step 2: Set Your Account
```bash
# Use the email shown from step 1
gcloud config set account YOUR_EMAIL@gmail.com
```

## Step 3: Set Project
```bash
gcloud config set project vutils
```

## Step 4: Verify Configuration
```bash
gcloud config list
```

## Step 5: Enable Cloud Resource Manager API
```bash
gcloud services enable cloudresourcemanager.googleapis.com
```

## Step 6: Wait & Retry
Wait 2-3 minutes for API to propagate, then:

1. Go to GitHub → **Actions** tab
2. Click on failed workflow
3. Click **Re-run all jobs**

---

## Alternative: Enable via GCP Console (Easier!)

If Cloud Shell auth keeps failing:

1. Go to [API Library](https://console.cloud.google.com/apis/library)
2. Select project: **vutils**
3. Search for: **Cloud Resource Manager API**
4. Click **Enable**
5. Wait 2 minutes
6. Retry GitHub Actions workflow

This is actually faster than troubleshooting Cloud Shell auth!

---

## What's Left

After enabling this API, the deployment should complete:
- ✅ Docker image (already done!)
- ⏳ Terraform (needs this API)
- ⏳ Cloud Functions deployment
- ⏳ Cloud Run deployment

You're very close! 🚀
