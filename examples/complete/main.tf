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
  region  = "us-central1"
}

module "imgproxy" {
  source = "github.com/imgproxy/terraform-google-imgproxy"

  project_id   = var.project_id
  location     = "us-central1"
  service_name = "imgproxy"
  description  = "imgproxy image processing service"
  tag          = "v4"

  # Security: request signing
  keys_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-keys"
  }
  salts_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-salts"
  }
  signature_size = 32

  # Optional: Bearer token auth (cannot be used with enable_cdn = true)
  # secret_secret = {
  #   id = "projects/${var.project_id}/secrets/imgproxy-secret"
  # }

  # Optional: source URL encryption
  # source_url_encryption_key_secret = {
  #   id = "projects/${var.project_id}/secrets/imgproxy-source-url-key"
  # }

  # imgproxy Pro
  pro = true
  pro_license_key_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-pro-license"
  }
  repo_password_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-pro-password"
  }

  # Optional: pull from your own registry instead (pro then no longer affects the image)
  # repo          = "registry.example.com/imgproxy-custom"
  # repo_username = "deploy"

  # Optional: trusted signatures (Pro only)
  # trusted_signatures_secret = {
  #   id = "projects/${var.project_id}/secrets/imgproxy-trusted-sigs"
  # }

  # Optional: additional secrets for third-party integrations
  # secrets = {
  #   IMGPROXY_NEW_RELIC_KEY = { id = "projects/${var.project_id}/secrets/newrelic-license" }
  #   IMGPROXY_SENTRY_DSN    = { id = "projects/${var.project_id}/secrets/sentry-dsn", version = "3" }
  # }

  # Existing buckets (see README): source images and result cache (Pro)
  source_buckets = ["${var.project_id}-imgproxy-complete-source"]
  cache_bucket   = "${var.project_id}-imgproxy-complete-cache"

  # Monitoring (OpenTelemetry collector sidecar)
  enable_monitoring = true

  # Compute resources
  cpu     = 2
  memory  = "2Gi"
  workers = 4
  timeout = 60

  # Scaling
  min_instances = 2
  max_instances = 20

  # Access control
  ingress               = "INGRESS_TRAFFIC_ALL"
  allow_unauthenticated = true

  # Labels
  service_labels = {
    app  = "imgproxy"
    team = "platform"
  }

  # Optional: Cloud CDN (requires a domain name)
  # enable_cdn                 = true
  # cdn_domains                = ["cdn.example.com"]
  # cdn_cache_mode             = "CACHE_ALL_STATIC"
  # cdn_default_ttl            = 3600
  # cdn_max_ttl                = 86400
  # cdn_client_ttl             = 3600
  # cdn_negative_caching       = true
  # cdn_redirect_http_to_https = true

  # Additional imgproxy configuration
  environment = {
    IMGPROXY_MAX_SRC_RESOLUTION = "50.0"
    IMGPROXY_JPEG_PROGRESSIVE   = "true"
    IMGPROXY_CACHE_USE          = "gcs"
    IMGPROXY_CACHE_BUCKET       = "${var.project_id}-imgproxy-complete-cache"
  }
}

output "url" {
  description = "The URL of the deployed imgproxy Cloud Run service"
  value       = module.imgproxy.url
}

output "cdn_ip_address" {
  description = "Static IP address of the CDN load balancer (when CDN enabled)"
  value       = module.imgproxy.cdn_ip_address
}
