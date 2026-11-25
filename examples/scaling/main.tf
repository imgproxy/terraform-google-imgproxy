terraform {
  required_version = ">= 1.15"

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
  source  = "imgproxy/imgproxy/google"
  version = "~> 0.1"

  project_id   = var.project_id
  location     = "us-central1"
  service_name = "imgproxy"
  tag          = "v4"

  # Request signing (required for production)
  keys_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-keys"
  }
  salts_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-salts"
  }

  # Instance size
  cpu    = 1
  memory = "1024Mi"

  # Concurrency. Cloud Run sends an instance at most this many simultaneous requests and starts
  # another instance beyond that. Also sets IMGPROXY_WORKERS (default: cpu x 2).
  workers = 2

  # Instance count. Cloud Run adds and removes instances between these bounds.
  min_instances = 1 # 1 avoids cold starts; 0 would scale to zero and save cost
  max_instances = 10
  # service_scaling = { min_instance_count = 1 } # service-level minimum, independent of revisions (the revision's min_instances is the usual choice)

  # CPU and sandbox
  cpu_idle              = true # throttle the CPU between requests; false keeps it always allocated (billed continuously)
  execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

  # Session affinity: route a client's requests to the same instance when possible. Leave it off
  # for imgproxy, which is stateless.
  # session_affinity = "true"
}

output "url" {
  value = module.imgproxy.url
}
