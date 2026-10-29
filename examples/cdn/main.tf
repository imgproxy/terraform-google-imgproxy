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
  service_name = "imgproxy"
  tag          = "v4"

  keys_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-keys"
  }
  salts_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-salts"
  }

  enable_cdn  = true
  cdn_domains = ["cdn.example.com"] # Domain for the managed SSL certificate

  cdn_cache_mode  = "CACHE_ALL_STATIC"
  cdn_default_ttl = 3600
  cdn_max_ttl     = 86400
  cdn_client_ttl  = 3600

  cdn_redirect_http_to_https = true
}

output "cdn_ip" {
  value       = module.imgproxy.cdn_ip_address
  description = "Point your DNS A record to this IP"
}

output "cert_status" {
  value       = module.imgproxy.cdn_managed_certificate_id
  description = "SSL certificate ID, check its status in Cloud Console"
}
