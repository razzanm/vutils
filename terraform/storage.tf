# Uploads bucket - stores original video files
resource "google_storage_bucket" "uploads" {
  name          = "${var.project_id}-uploads"
  location      = var.region
  force_destroy = true  # Allow deletion even with objects (use with caution in prod)
  
  uniform_bucket_level_access = true
  
  cors {
    origin          = ["*"]  # Configure specific origins in production
    method          = ["GET", "HEAD", "PUT", "POST"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
  
  lifecycle_rule {
    condition {
      age = var.bucket_lifecycle_days
    }
    action {
      type = "Delete"
    }
  }
  
  labels = {
    environment = var.environment
    purpose     = "video-uploads"
  }
}

# Outputs bucket - stores converted video files
resource "google_storage_bucket" "outputs" {
  name          = "${var.project_id}-outputs"
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
  
  cors {
    origin          = ["*"]  # Configure specific origins in production
    method          = ["GET", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
  
  lifecycle_rule {
    condition {
      age = var.bucket_lifecycle_days
    }
    action {
      type = "Delete"
    }
  }
  
  labels = {
    environment = var.environment
    purpose     = "video-outputs"
  }
}

# Functions source code bucket
resource "google_storage_bucket" "functions_source" {
  name          = "${var.project_id}-functions-source"
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
  
  labels = {
    environment = var.environment
    purpose     = "functions-source"
  }
}
