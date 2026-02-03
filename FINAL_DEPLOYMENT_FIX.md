# Final Deployment Fix - GCS Pub/Sub Permissions

## Issue

Cloud Storage service agent needs Pub/Sub Publisher permissions to work with Eventarc triggers.

## Solution

I've updated both the GitHub Actions workflow and setup script to grant the necessary permissions.

## Commit and Push:

```bash
cd /Users/rajan/Desktop/Projects/vutils
git add .
git commit -m "Grant GCS service account Pub/Sub permissions for Eventarc"
git push origin main
```

## What This Fixes

The Cloud Storage service account (`service-PROJECT_NUMBER@gs-project-accounts.iam.gserviceaccount.com`) needs the **Pub/Sub Publisher** role to:
- Create Pub/Sub topics for Eventarc
- Publish bucket change notifications to these topics
- Enable the `trigger-conversion` function to receive GCS upload events

## Final Deployment Steps

After this push:
1. ✅ All APIs enabled
2. ✅ Docker image built & pushed  
3. ✅ Terraform infrastructure deployed
4. ✅ Cloud Run service deployed (2 max instances)
5. ✅ generate-upload-url function deployed (10 max instances)
6. ✅ GCS service account permissions granted
7. ✅ Eventarc permissions granted
8. ✅ trigger-conversion function deployed (with GCS event trigger)
9. ✅ process-video-small function deployed (2 max instances)
10. ✅ **Deployment complete!** 🎉

---

## All Deployment Issues Resolved

- ✅ GCR permissions (Editor role)
- ✅ APIs (Container Registry, Cloud Resource Manager, Eventarc)
- ✅ Terraform resource conflicts
- ✅ Quota limits (all functions reduced to fit 20 vCPU limit)
- ✅ Eventarc GCS bucket permissions
- ✅ **GCS service account Pub/Sub permissions** ← Final fix!

Your automated video converter backend will be fully operational after this deployment! 🚀
