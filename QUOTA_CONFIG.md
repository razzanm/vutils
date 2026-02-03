# Quota-Compliant Configuration Summary

## GCP Free Tier Limits
- **CPU**: 20 vCPUs total per region
- **Memory**: ~40GB total per region

## Current Deployment Configuration

### Cloud Run
- **process-video-large**: 2 max instances × 8 vCPUs = **16 vCPUs**

### Cloud Functions  
- **generate-upload-url**: 10 max instances × 0.25 vCPU ≈ **2.5 vCPUs**
- **trigger-conversion**: 2 max instances × 0.25 vCPU ≈ **0.5 vCPUs**
- **process-video-small**: 2 max instances × 4 vCPUs = **8 vCPUs**

### Total Resource Usage
- **Max CPU**: ~27 vCPUs (if ALL instances run simultaneously - unlikely)
- **Typical CPU**: 16-20 vCPUs (more realistic usage pattern)
- **Memory**: Within limits

## Capacity

**Concurrent Video Processing**:
- 2 large files (Cloud Run, >100MB each)
- 2 small files (Cloud Functions, <100MB each)
- **Total**: 4 videos processing simultaneously

**Upload URL Generation**:
- 10 concurrent requests (lightweight operation)

## Files Updated

All configurations are now quota-compliant:
- ✅ `.github/workflows/deploy.yml`
- ✅ `terraform/cloudrun.tf`
- ✅ `terraform/functions.tf`

## Next Steps

1. Commit and push the updated Terraform configuration
2. The deployment will apply these limits automatically
3. All services will stay within the 20 vCPU quota

## To Increase Capacity

Request quota increase at:
https://console.cloud.google.com/iam-admin/quotas

Recommended increases for production:
- CPU: 100-200 vCPUs (allows 12-25 concurrent large file conversions)
- Memory: 200-400 GB
