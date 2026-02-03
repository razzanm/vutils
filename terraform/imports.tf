# Terraform Import Configuration
# This file tells Terraform to import existing resources instead of trying to create them

# Import existing service accounts
import {
  to = google_service_account.cloudrun_processor
  id = "projects/vutils/serviceAccounts/cloudrun-processor@vutils.iam.gserviceaccount.com"
}

import {
  to = google_service_account.functions
  id = "projects/vutils/serviceAccounts/functions-processor@vutils.iam.gserviceaccount.com"
}

# Import existing storage buckets
import {
  to = google_storage_bucket.uploads
  id = "vutils-uploads"
}

import {
  to = google_storage_bucket.outputs
  id = "vutils-outputs"
}

import {
  to = google_storage_bucket.functions_source
  id = "vutils-functions-source"
}

# Import existing Firestore database
import {
  to = google_firestore_database.main
  id = "projects/vutils/databases/(default)"
}
