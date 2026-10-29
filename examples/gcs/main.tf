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

resource "google_storage_bucket" "images" {
  name                        = "${var.project_id}-imgproxy-images"
  location                    = "us-central1"
  uniform_bucket_level_access = true
}

module "imgproxy" {
  source = "github.com/imgproxy/terraform-google-imgproxy"

  project_id   = var.project_id
  location     = "us-central1"
  service_name = "imgproxy"
  tag          = "v4"

  keys_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-keys"
  }
  salts_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-salts"
  }

  # Grants read access to the bucket and enables the gs:// URL scheme
  source_buckets = [google_storage_bucket.images.name]
}

output "url" {
  value = module.imgproxy.url
}
