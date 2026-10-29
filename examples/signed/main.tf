variable "project_id" {
  description = "GCP project ID"
  type        = string
}

module "imgproxy" {
  source = "github.com/imgproxy/terraform-google-imgproxy"

  project_id   = var.project_id
  service_name = "imgproxy"

  # Request signing (required for production)
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
