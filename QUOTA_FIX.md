# GCP Quota Fix - Free Tier Limits

## Problem

Your GCP project has default quotas that are much lower than our original configuration:

**Default Quotas** (Free Tier):
- CPU: 20 vCPUs total per region
- Memory: ~40GB total per region

**Original Config**:
- Cloud Run: 100 instances × 8 vCPUs = 800 vCPUs ❌
- Cloud Functions: 100 instances × 4 vCPUs = 400 vCPUs ❌

## Solution

Reduced to fit within free tier:

**New Config**:
- Cloud Run: **2 max instances** × 8 vCPUs = 16 vCPUs ✅
- Cloud Functions: **2 max instances** × 4 vCPUs = 8 vCPUs (shared with other functions) ✅

## What This Means

**Capacity**:
- 2 large file conversions can run at once (Cloud Run)
- 2 small file conversions can run at once (Cloud Functions)
- Total: Up to 4 concurrent video conversions

**For Higher Capacity**:
Request quota increase:
1. Go to [Quotas Page](https://console.cloud.google.com/iam-admin/quotas?filter=run)
2. Search: "Cloud Run CPU allocation per region"
3. Click checkbox → **Edit Quotas**
4. Request increase (e.g., 200 vCPUs for 25 large + 25 small concurrent conversions)

## Deploy Now

The code has been updated. Commit and push:

```bash
git add .
git commit -m "Reduce max instances to fit GCP free tier quota"
git push origin main
```

The deployment will now succeed! 🚀

---

**Note**: 2 concurrent large files + 2 concurrent small files is still quite good for a free tier deployment!
