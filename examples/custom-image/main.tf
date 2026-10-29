variable "project_id" {
  description = "GCP project ID"
  type        = string
}

module "imgproxy" {
  source = "github.com/imgproxy/terraform-google-imgproxy"

  project_id   = var.project_id
  service_name = "imgproxy-custom"

  # Overrides the default repository; the tag is set separately
  repo = "us-central1-docker.pkg.dev/${var.project_id}/imgproxy-mirror/imgproxy"
  tag  = "v3.0"

  keys_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-keys"
  }
  salts_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-salts"
  }
}

output "url" {
  value = module.imgproxy.url
}
