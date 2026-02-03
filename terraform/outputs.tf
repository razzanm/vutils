output "upload_bucket_name" {
  description = "Name of the upload GCS bucket"
  value       = google_storage_bucket.uploads.name
}

output "output_bucket_name" {
  description = "Name of the output GCS bucket"
  value       = google_storage_bucket.outputs.name
}

output "generate_upload_url_function_url" {
  description = "URL of the generate upload URL function"
  value       = google_cloudfunctions2_function.generate_upload_url.url
}

output "process_small_function_url" {
  description = "URL of the small file processor function"
  value       = google_cloudfunctions2_function.process_video_small.url
}

output "process_large_service_url" {
  description = "URL of the large file processor Cloud Run service"
  value       = google_cloud_run_v2_service.process_video_large.uri
}

output "firestore_database" {
  description = "Firestore database name"
  value       = google_firestore_database.main.name
}
