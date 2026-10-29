terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

provider "google" {
  project = var.project_id
}

resource "google_storage_bucket" "source" {
  name                        = "${var.project_id}-imgproxy-source"
  location                    = "us-central1"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "cache" {
  name                        = "${var.project_id}-imgproxy-cache"
  location                    = "us-central1"
  uniform_bucket_level_access = true
}

module "imgproxy" {
  source = "github.com/imgproxy/terraform-google-imgproxy"

  project_id   = var.project_id
  location     = "us-central1"
  service_name = "imgproxy-pro"
  tag          = "v4"

  pro = true
  pro_registry_password_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-pro-password"
  }
  pro_license_key_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-pro-license"
  }

  keys_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-keys"
  }
  salts_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-salts"
  }

  # Source images and processed-result cache (Pro)
  source_buckets = [google_storage_bucket.source.name]
  cache_bucket   = google_storage_bucket.cache.name

  environment = {
    IMGPROXY_CACHE_USE    = "gcs"
    IMGPROXY_CACHE_BUCKET = google_storage_bucket.cache.name
  }
}

output "url" {
  value = module.imgproxy.url
}
