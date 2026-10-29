provider "google" {
  project = var.project_id
  region  = var.location
}

resource "google_storage_bucket" "source" {
  for_each                    = toset(var.source_buckets)
  name                        = each.value
  location                    = var.location
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "cache" {
  count                       = var.cache_bucket != null ? 1 : 0
  name                        = var.cache_bucket
  location                    = var.location
  uniform_bucket_level_access = true
}

module "imgproxy" {
  source = "github.com/imgproxy/terraform-gcs"

  project_id   = var.project_id
  location     = var.location
  service_name = var.service_name
  description  = var.description

  # Security: request signing
  keys_secret                      = var.keys_secret
  salts_secret                     = var.salts_secret
  signature_size                   = var.signature_size
  secret_secret                    = var.secret_secret
  source_url_encryption_key_secret = var.source_url_encryption_key_secret

  # imgproxy version and edition
  tag = var.tag
  pro = var.pro

  # imgproxy Pro configuration
  pro_license_key_secret       = var.pro_license_key_secret
  pro_registry_password_secret = var.pro_registry_password_secret
  trusted_signatures_secret    = var.trusted_signatures_secret

  # Additional secrets (e.g. New Relic, Sentry, OpenTelemetry)
  secrets = var.secrets

  # GCS integration
  source_buckets = [for b in google_storage_bucket.source : b.name]
  cache_bucket   = try(google_storage_bucket.cache[0].name, null)

  # Monitoring
  enable_monitoring    = var.enable_monitoring
  otel_collector_config = var.otel_collector_config

  # Compute resources
  cpu                   = var.cpu
  memory                = var.memory
  cpu_idle              = var.cpu_idle
  workers               = var.workers
  timeout               = var.timeout
  execution_environment = var.execution_environment

  # Scaling
  min_instances   = var.min_instances
  max_instances   = var.max_instances
  service_scaling = var.service_scaling

  # Access control
  ingress               = var.ingress
  allow_unauthenticated = var.allow_unauthenticated

  # Labels
  service_labels  = var.service_labels
  template_labels = var.template_labels

  # Cloud CDN
  enable_cdn                 = var.enable_cdn
  cdn_domains                = var.cdn_domains
  cdn_ssl_certificates       = var.cdn_ssl_certificates
  cdn_cache_mode             = var.cdn_cache_mode
  cdn_default_ttl            = var.cdn_default_ttl
  cdn_max_ttl                = var.cdn_max_ttl
  cdn_client_ttl             = var.cdn_client_ttl
  cdn_negative_caching       = var.cdn_negative_caching
  cdn_redirect_http_to_https = var.cdn_redirect_http_to_https

  # Additional imgproxy configuration
  environment = {
    IMGPROXY_MAX_SRC_RESOLUTION = "50.0"
    IMGPROXY_JPEG_PROGRESSIVE   = "true"
  }
}

output "url" {
  description = "The URL of the deployed imgproxy Cloud Run service"
  value       = module.imgproxy.url
}

output "service_name" {
  description = "The Cloud Run service name"
  value       = module.imgproxy.service_name
}

output "service_account_email" {
  description = "Email of the imgproxy service account"
  value       = module.imgproxy.service_account_email
}

output "cdn_ip_address" {
  description = "Static IP address of the CDN load balancer (when CDN enabled)"
  value       = module.imgproxy.cdn_ip_address
}

output "cdn_managed_certificate_id" {
  description = "ID of the managed SSL certificate (when CDN enabled with managed cert)"
  value       = module.imgproxy.cdn_managed_certificate_id
}
