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
  default     = "imgproxy"
  description = "Name for the Cloud Run service and resource prefix"
}

variable "description" {
  type        = string
  default     = null
  description = "Cloud Run service description"
}

variable "keys_secret" {
  type = object({
    id      = string
    version = optional(string, "latest")
  })
  description = "Secret Manager secret containing signing keys (comma-separated hex-encoded values)"
}

variable "salts_secret" {
  type = object({
    id      = string
    version = optional(string, "latest")
  })
  description = "Secret Manager secret containing signing salts (comma-separated hex-encoded values)"
}

variable "signature_size" {
  type        = number
  default     = 32
  description = "Number of bytes from the key/salt used for signing"
}

variable "secret_secret" {
  type = object({
    id      = string
    version = optional(string, "latest")
  })
  default     = null
  description = "Secret Manager secret for the authorization token (IMGPROXY_SECRET)"
}

variable "source_url_encryption_key_secret" {
  type = object({
    id      = string
    version = optional(string, "latest")
  })
  default     = null
  description = "Secret Manager secret for the source URL encryption key"
}

variable "tag" {
  type        = string
  default     = "v4"
  description = "imgproxy image tag (version)"
}

variable "pro" {
  type        = bool
  default     = false
  description = "Use imgproxy Pro instead of community image"
}


variable "pro_license_key_secret" {
  type = object({
    id      = string
    version = optional(string, "latest")
  })
  default     = null
  description = "Secret Manager secret for the imgproxy Pro license key. Required when pro = true."
}

variable "pro_registry_password_secret" {
  type = object({
    id      = string
    version = optional(string, "latest")
  })
  default     = null
  description = "Secret Manager secret for the docker.imgproxy.pro registry password. Required when pro = true."
}

variable "trusted_signatures_secret" {
  type = object({
    id      = string
    version = optional(string, "latest")
  })
  default     = null
  description = "Secret Manager secret for trusted signature prefixes (imgproxy Pro only)"
}

variable "secrets" {
  type = map(object({
    id      = string
    version = optional(string, "latest")
  }))
  default     = {}
  description = "Map of environment variable names to Secret Manager secrets"
}

variable "source_buckets" {
  type        = list(string)
  default     = []
  description = "GCS bucket names for imgproxy source images"
}

variable "cache_bucket" {
  type        = string
  default     = null
  description = "GCS bucket name for imgproxy result cache (Pro only)"
}

variable "enable_monitoring" {
  type        = bool
  default     = false
  description = "Enable the OpenTelemetry collector sidecar for traces, metrics, and logs"
}

variable "otel_collector_config" {
  type        = string
  default     = <<-EOT
    receivers:
      otlp:
        protocols:
          http:
            endpoint: 0.0.0.0:4318
          grpc:
            endpoint: 0.0.0.0:4317

    processors:
      batch:

    exporters:
      googlecloud:
        project: $${GOOGLE_CLOUD_PROJECT}
        metric:
          prefix: workload.googleapis.com
        log:
          default_log_name: imgproxy

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch]
          exporters: [googlecloud]
        metrics:
          receivers: [otlp]
          processors: [batch]
          exporters: [googlecloud]
        logs:
          receivers: [otlp]
          processors: [batch]
          exporters: [googlecloud]
  EOT
  description = "OpenTelemetry collector config mounted at /etc/otel/config.yaml when monitoring is enabled"
}

variable "cpu" {
  type        = number
  default     = 2
  description = "CPU limit for the container (e.g. 1, 2)"
}

variable "memory" {
  type        = string
  default     = "2Gi"
  description = "Memory limit for the container (e.g. \"512Mi\", \"2Gi\")"
}

variable "cpu_idle" {
  type        = bool
  default     = true
  description = "Throttle CPU when idle. Set to false to keep CPU always allocated"
}

variable "workers" {
  type        = number
  default     = null
  description = "Number of concurrent requests per instance"
}

variable "timeout" {
  type        = number
  default     = null
  description = "Request timeout in seconds"
}

variable "execution_environment" {
  type        = string
  default     = "EXECUTION_ENVIRONMENT_GEN2"
  description = "Sandbox environment for the revision (EXECUTION_ENVIRONMENT_GEN1 or EXECUTION_ENVIRONMENT_GEN2)"
}

variable "min_instances" {
  type        = number
  default     = 1
  description = "Minimum number of Cloud Run instances (set to 1 to avoid cold starts)"
}

variable "max_instances" {
  type        = number
  default     = 10
  description = "Maximum number of Cloud Run instances"
}

variable "service_scaling" {
  type = object({
    min_instance_count = optional(number)
  })
  default     = null
  description = "Service-level minimum instance count (independent of revision scaling)"
}

variable "ingress" {
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"
  description = "Cloud Run ingress setting"
}

variable "allow_unauthenticated" {
  type        = bool
  default     = true
  description = "Whether to allow unauthenticated (public) requests"
}

variable "service_labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to the Cloud Run service"
}

variable "template_labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to the Cloud Run revision template"
}

variable "enable_cdn" {
  type        = bool
  default     = false
  description = "Enable Cloud CDN with global HTTPS load balancer"
}

variable "cdn_domains" {
  type        = list(string)
  default     = []
  description = "Domain names for managed SSL certificates (e.g. [\"cdn.example.com\"])"
}

variable "cdn_ssl_certificates" {
  type        = list(string)
  default     = []
  description = "Names of existing SSL certificate resources (mutually exclusive with cdn_domains)"
}

variable "cdn_cache_mode" {
  type        = string
  default     = "CACHE_ALL_STATIC"
  description = "CDN cache mode (CACHE_ALL_STATIC, USE_ORIGIN_HEADERS, FORCE_CACHE_ALL)"
}

variable "cdn_default_ttl" {
  type        = number
  default     = 3600
  description = "Default TTL in seconds for cached content"
}

variable "cdn_max_ttl" {
  type        = number
  default     = 86400
  description = "Maximum TTL in seconds for cached content"
}

variable "cdn_client_ttl" {
  type        = number
  default     = 3600
  description = "Client (browser) TTL in seconds"
}

variable "cdn_negative_caching" {
  type        = bool
  default     = true
  description = "Enable caching of error responses (4xx, 5xx)"
}

variable "cdn_redirect_http_to_https" {
  type        = bool
  default     = true
  description = "Automatically redirect HTTP traffic to HTTPS"
}
