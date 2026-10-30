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

  # Existing bucket (see README) for the processed-result cache (Pro)
  cache_bucket = "${var.project_id}-imgproxy-cache"

  environment = {
    IMGPROXY_CACHE_USE    = "gcs"
    IMGPROXY_CACHE_BUCKET = "${var.project_id}-imgproxy-cache"
  }
}

output "url" {
  value = module.imgproxy.url
}
