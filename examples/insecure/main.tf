provider "google" {
  project = var.project_id
  region  = var.location
}

module "imgproxy" {
  source = "github.com/imgproxy/terraform-gcs"

  project_id   = var.project_id
  location     = var.location
  service_name = var.service_name

  # WARNING: Insecure mode - no request signing
  # Use only for development/testing
  insecure = true

  tag = var.tag
}

output "url" {
  description = "The URL of the deployed imgproxy service"
  value       = module.imgproxy.url
}

output "warning" {
  description = "Security warning"
  value       = "⚠️  This deployment runs in INSECURE mode with no request signing. Do not use in production!"
}
