variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "location" {
  type        = string
  default     = "us-central1"
  description = "GCP location for all resources"
}

variable "service_name" {
  type        = string
  default     = "imgproxy-insecure"
  description = "Name for the Cloud Run service"
}

variable "tag" {
  type        = string
  default     = "latest"
  description = "imgproxy image tag (version)"
}
