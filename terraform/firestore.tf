# Enable required APIs
resource "google_project_service" "firestore" {
  service            = "firestore.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "appengine" {
  service            = "appengine.googleapis.com"
  disable_on_destroy = false
}

# Firestore database
resource "google_firestore_database" "main" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"
  
  depends_on = [
    google_project_service.firestore,
    google_project_service.appengine
  ]
}

# Firestore index for querying QUEUED jobs ordered by createdAt
resource "google_firestore_index" "conversion_jobs_queued" {
  project    = var.project_id
  database   = google_firestore_database.main.name
  collection = "conversion-jobs"
  
  fields {
    field_path = "status"
    order      = "ASCENDING"
  }
  
  fields {
    field_path = "createdAt"
    order      = "ASCENDING"
  }
}

# Firestore index for querying PROCESSING jobs (for cleanup)
resource "google_firestore_index" "conversion_jobs_processing" {
  project    = var.project_id
  database   = google_firestore_database.main.name
  collection = "conversion-jobs"
  
  fields {
    field_path = "status"
    order      = "ASCENDING"
  }
  
  fields {
    field_path = "claimedAt"
    order      = "ASCENDING"
  }
}
