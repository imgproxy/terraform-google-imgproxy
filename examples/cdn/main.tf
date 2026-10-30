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

  enable_cdn = true

  # With a domain, a managed SSL certificate is provisioned (set cdn_redirect_http_to_https = true):
  # cdn_domains = ["cdn.example.com"]

  cdn_cache_mode  = "CACHE_ALL_STATIC"
  cdn_default_ttl = 3600
  cdn_max_ttl     = 86400
  cdn_client_ttl  = 3600

  # HTTP only, for testing without a domain; the url output is http://<static-ip>
  cdn_redirect_http_to_https = false
}

output "url" {
  value = module.imgproxy.url
}

output "cdn_ip" {
  value       = module.imgproxy.cdn_ip_address
  description = "Static IP of the CDN load balancer"
}

output "cert_status" {
  value       = module.imgproxy.cdn_managed_certificate_id
  description = "SSL certificate ID, check its status in Cloud Console"
}
