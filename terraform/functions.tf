# Enable required APIs
resource "google_project_service" "cloudfunctions" {
  service            = "cloudfunctions.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudbuild" {
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

# Archive function source code
data "archive_file" "generate_upload_url" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/generate-upload-url"
  output_path = "${path.module}/.terraform/tmp/generate-upload-url.zip"
}

data "archive_file" "trigger_conversion" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/trigger-conversion"
  output_path = "${path.module}/.terraform/tmp/trigger-conversion.zip"
}

data "archive_file" "process_video_small" {
  type        = "zip"
  source_dir  = "${path.module}/../functions/process-video-small"
  output_path = "${path.module}/.terraform/tmp/process-video-small.zip"
}

# Upload function source to GCS
resource "google_storage_bucket_object" "generate_upload_url" {
  name   = "generate-upload-url-${data.archive_file.generate_upload_url.output_md5}.zip"
  bucket = google_storage_bucket.functions_source.name
  source = data.archive_file.generate_upload_url.output_path
}

resource "google_storage_bucket_object" "trigger_conversion" {
  name   = "trigger-conversion-${data.archive_file.trigger_conversion.output_md5}.zip"
  bucket = google_storage_bucket.functions_source.name
  source = data.archive_file.trigger_conversion.output_path
}

resource "google_storage_bucket_object" "process_video_small" {
  name   = "process-video-small-${data.archive_file.process_video_small.output_md5}.zip"
  bucket = google_storage_bucket.functions_source.name
  source = data.archive_file.process_video_small.output_path
}

# Cloud Function: Generate Upload URL
resource "google_cloudfunctions2_function" "generate_upload_url" {
  name        = "generate-upload-url"
  location    = var.region
  description = "Generates signed URL for video upload"
  
  build_config {
    runtime     = "python311"
    entry_point = "generate_upload_url"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.generate_upload_url.name
      }
    }
  }
  
  service_config {
    max_instance_count    = 100
    min_instance_count    = 0
    available_memory      = "256Mi"
    timeout_seconds       = 60
    service_account_email = google_service_account.functions.email
    
    environment_variables = {
      PROJECT_ID              = var.project_id
      UPLOAD_BUCKET           = google_storage_bucket.uploads.name
      MAX_FILE_SIZE_MB        = var.max_file_size_mb
      FIRESTORE_DATABASE      = google_firestore_database.main.name
    }
  }
  
  depends_on = [
    google_project_service.cloudfunctions,
    google_project_service.cloudbuild
  ]
}

# Cloud Function: Trigger Conversion (GCS-triggered)
resource "google_cloudfunctions2_function" "trigger_conversion" {
  name        = "trigger-conversion"
  location    = var.region
  description = "Triggered on file upload, delegates to appropriate processor"
  
  build_config {
    runtime     = "python311"
    entry_point = "trigger_conversion"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.trigger_conversion.name
      }
    }
  }
  
  service_config {
    max_instance_count    = 100
    min_instance_count    = 0
    available_memory      = "512Mi"
    timeout_seconds       = 60
    service_account_email = google_service_account.functions.email
    
    environment_variables = {
      PROJECT_ID                = var.project_id
      UPLOAD_BUCKET             = google_storage_bucket.uploads.name
      SMALL_FILE_THRESHOLD_MB   = var.small_file_threshold_mb
      SMALL_PROCESSOR_URL       = google_cloudfunctions2_function.process_video_small.url
      LARGE_PROCESSOR_URL       = google_cloud_run_v2_service.process_video_large.uri
      FIRESTORE_DATABASE        = google_firestore_database.main.name
    }
  }
  
  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.storage.object.v1.finalized"
    retry_policy   = "RETRY_POLICY_RETRY"
    
    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.uploads.name
    }
  }
  
  depends_on = [
    google_project_service.cloudfunctions,
    google_project_service.cloudbuild
  ]
}

# Cloud Function: Process Small Videos
resource "google_cloudfunctions2_function" "process_video_small" {
  name        = "process-video-small"
  location    = var.region
  description = "Processes small video files (<100MB) with 4vCPU/8GB"
  
  build_config {
    runtime     = "python311"
    entry_point = "process_video"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.process_video_small.name
      }
    }
  }
  
  service_config {
    max_instance_count               = 100
    min_instance_count               = 0
    available_memory                 = "8Gi"
    available_cpu                    = "4"
    timeout_seconds                  = 1800  # 30 minutes
    max_instance_request_concurrency = 1     # 1 job per instance
    service_account_email            = google_service_account.functions.email
    
    environment_variables = {
      PROJECT_ID         = var.project_id
      UPLOAD_BUCKET      = google_storage_bucket.uploads.name
      OUTPUT_BUCKET      = google_storage_bucket.outputs.name
      FIRESTORE_DATABASE = google_firestore_database.main.name
      PROCESSOR_TYPE     = "cloud-function"
    }
  }
  
  depends_on = [
    google_project_service.cloudfunctions,
    google_project_service.cloudbuild
  ]
}
