# Service account for Cloud Run (large file processor)
resource "google_service_account" "cloudrun_processor" {
  account_id   = "cloudrun-processor"
  display_name = "Cloud Run Video Processor"
  description  = "Service account for large file video processing"
}

# Service account for Cloud Functions
resource "google_service_account" "functions" {
  account_id   = "functions-processor"
  display_name = "Cloud Functions Processor"
  description  = "Service account for Cloud Functions (upload URL, trigger, small processor)"
}

# Grant Cloud Run SA access to GCS buckets
resource "google_storage_bucket_iam_member" "cloudrun_uploads_read" {
  bucket = google_storage_bucket.uploads.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cloudrun_processor.email}"
}

resource "google_storage_bucket_iam_member" "cloudrun_outputs_write" {
  bucket = google_storage_bucket.outputs.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloudrun_processor.email}"
}

# Grant Cloud Functions SA access to GCS buckets
resource "google_storage_bucket_iam_member" "functions_uploads_read" {
  bucket = google_storage_bucket.uploads.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.functions.email}"
}

resource "google_storage_bucket_iam_member" "functions_uploads_admin" {
  bucket = google_storage_bucket.uploads.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.functions.email}"
}

resource "google_storage_bucket_iam_member" "functions_outputs_write" {
  bucket = google_storage_bucket.outputs.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.functions.email}"
}

# Grant Firestore access to both service accounts
resource "google_project_iam_member" "cloudrun_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.cloudrun_processor.email}"
}

resource "google_project_iam_member" "functions_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.functions.email}"
}

# Allow functions to invoke Cloud Run
resource "google_project_iam_member" "functions_cloudrun_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.functions.email}"
}

# Allow functions to invoke other Cloud Functions  
resource "google_project_iam_member" "functions_invoker" {
  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.functions.email}"
}

# Allow public access to generate-upload-url function (will be invoked by clients)
resource "google_cloudfunctions2_function_iam_member" "generate_upload_url_invoker" {
  project        = var.project_id
  location       = var.region
  cloud_function = google_cloudfunctions2_function.generate_upload_url.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}
