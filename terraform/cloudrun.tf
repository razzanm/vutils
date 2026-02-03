# Cloud Run service for large video processing
resource "google_cloud_run_v2_service" "process_video_large" {
  name     = "process-video-large"
  location = var.region
  
  template {
    service_account = google_service_account.cloudrun_processor.email
    
    scaling {
      min_instance_count = 0
      max_instance_count = 100
    }
    
    max_instance_request_concurrency = 1  # 1 job per instance
    
    timeout = "3600s"  # 60 minutes
    
    containers {
      image = "gcr.io/${var.project_id}/process-video-large:latest"
      
      resources {
        limits = {
          cpu    = "8"
          memory = "16Gi"
        }
      }
      
      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }
      
      env {
        name  = "UPLOAD_BUCKET"
        value = google_storage_bucket.uploads.name
      }
      
      env {
        name  = "OUTPUT_BUCKET"
        value = google_storage_bucket.outputs.name
      }
      
      env {
        name  = "FIRESTORE_DATABASE"
        value = google_firestore_database.main.name
      }
      
      env {
        name  = "PROCESSOR_TYPE"
        value = "cloud-run"
      }
    }
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  depends_on = [google_project_service.run]
}

# Allow authenticated invocations (from trigger function)
resource "google_cloud_run_v2_service_iam_member" "process_video_large_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.process_video_large.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.functions.email}"
}
