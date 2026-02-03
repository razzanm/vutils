variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region for deployment"
  type        = string
  default     = "asia-southeast1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "bucket_lifecycle_days" {
  description = "Number of days to retain files in GCS buckets"
  type        = number
  default     = 1  # 8 hours is less than a day, so we use 1 day minimum
}

variable "max_file_size_mb" {
  description = "Maximum file size in MB"
  type        = number
  default     = 1024  # 1GB
}

variable "small_file_threshold_mb" {
  description = "Threshold for small vs large file processing (MB)"
  type        = number
  default     = 100
}
