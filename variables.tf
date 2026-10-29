# ── Basic Configuration ───────────────────────────────────────────────────────

variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "location" {
  type        = string
  default     = "us-central1"
  description = "GCP location for all resources."
}

variable "service_name" {
  type        = string
  default     = "imgproxy"
  description = "Prefix applied to every resource name."
}

variable "tag" {
  type        = string
  default     = "v4"
  description = "imgproxy image tag (version)."
}

variable "repo" {
  type        = string
  default     = null
  description = "Custom container repository to use. When set, overrides the repository constructed from 'pro'. Combined with 'tag' to form the full image reference (e.g. 'gcr.io/my-project/imgproxy')."
}

variable "description" {
  type        = string
  default     = null
  description = "Cloud Run service description. This field currently has a 512-character limit."
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Enable Terraform deletion protection on the Cloud Run service. When true, `terraform destroy` requires first setting this to false and applying."
}

variable "environment" {
  type        = map(string)
  default     = {}
  description = "Additional environment variables passed to imgproxy (e.g. IMGPROXY_MAX_SRC_RESOLUTION)."
}

variable "secrets" {
  type = map(object({
    id      = string
    version = optional(string, "latest")
  }))
  default     = {}
  description = "Map of environment variable names to Secret Manager secrets. Example: {IMGPROXY_NEW_RELIC_KEY = { id = \"projects/PROJECT/secrets/newrelic-key\" }, IMGPROXY_SENTRY_DSN = { id = \"projects/PROJECT/secrets/sentry-dsn\", version = \"3\" }}."
}

# ── Security & Signing ────────────────────────────────────────────────────────

variable "keys_secret" {
  type = object({
    id      = string
    version = optional(string, "latest")
  })
  default     = null
  description = "Secret Manager secret containing imgproxy signing keys (comma-separated hex-encoded values). Required when insecure = false. Generate each key: openssl rand -hex 64. Sets IMGPROXY_KEY (https://docs.imgproxy.net/configuration/options#IMGPROXY_KEY)."
}

variable "salts_secret" {
  type = object({
    id      = string
    version = optional(string, "latest")
  })
  default     = null
  description = "Secret Manager secret containing imgproxy signing salts (comma-separated hex-encoded values). Must match the number of keys. Required when insecure = false. Sets IMGPROXY_SALT (https://docs.imgproxy.net/configuration/options#IMGPROXY_SALT)."
}

variable "insecure" {
  type        = bool
  default     = false
  description = "Disable URL signature checks. When true, key and salt are not required and no secrets are created."
}

variable "secret_secret" {
  type = object({
    id      = string
    version = optional(string, "latest")
  })
  default     = null
  description = "Secret Manager secret for the authorization token. When set, requests must include Authorization: Bearer <token>. Sets IMGPROXY_SECRET (https://docs.imgproxy.net/configuration/options#IMGPROXY_SECRET)."
}

variable "signature_size" {
  type        = number
  default     = 32
  description = "Number of bytes from the key/salt used for signing. Sets IMGPROXY_SIGNATURE_SIZE (https://docs.imgproxy.net/configuration/options#IMGPROXY_SIGNATURE_SIZE)."
}

variable "trusted_signatures_secret" {
  type = object({
    id      = string
    version = optional(string, "latest")
  })
  default     = null
  description = "Secret Manager secret for trusted signature prefixes. imgproxy Pro only. Sets IMGPROXY_TRUSTED_SIGNATURES (https://docs.imgproxy.net/configuration/options#IMGPROXY_TRUSTED_SIGNATURES)."
}

variable "source_url_encryption_key_secret" {
  type = object({
    id      = string
    version = optional(string, "latest")
  })
  default     = null
  description = "Secret Manager secret for the source URL encryption key. Sets IMGPROXY_SOURCE_URL_ENCRYPTION_KEY (https://docs.imgproxy.net/configuration/options#IMGPROXY_SOURCE_URL_ENCRYPTION_KEY)."
}

# ── Compute Resources ─────────────────────────────────────────────────────────

variable "cpu" {
  type        = number
  default     = 1
  description = "CPU limit for the container (e.g. 1, 2)."
}

variable "memory" {
  type        = string
  default     = "1024Mi"
  description = "Memory limit for the container (e.g. \"512Mi\", \"2Gi\")."
}

variable "workers" {
  type        = number
  default     = null
  description = "Number of concurrent requests per instance. Sets both IMGPROXY_WORKERS (https://docs.imgproxy.net/configuration/options#IMGPROXY_WORKERS) and max_instance_request_concurrency (Cloud Run). Defaults to cpu × 2."
}

variable "timeout" {
  type        = number
  default     = null
  description = "Request timeout in seconds. Sets IMGPROXY_TIMEOUT (https://docs.imgproxy.net/configuration/options#IMGPROXY_TIMEOUT) and CDN backend timeout_sec. Defaults to Cloud Run's default (300s) and CDN default (30s) when null."
}

variable "cpu_idle" {
  type        = bool
  default     = true
  description = "Throttle the CPU when no requests are being processed. Set to false to keep CPU always allocated."
}

variable "execution_environment" {
  type        = string
  default     = "EXECUTION_ENVIRONMENT_GEN2"
  description = "Sandbox environment for the revision."

  validation {
    condition     = contains(["EXECUTION_ENVIRONMENT_GEN1", "EXECUTION_ENVIRONMENT_GEN2"], var.execution_environment)
    error_message = "Must be EXECUTION_ENVIRONMENT_GEN1 or EXECUTION_ENVIRONMENT_GEN2."
  }
}

# ── Storage Integration ───────────────────────────────────────────────────────

variable "source_buckets" {
  type        = list(string)
  default     = []
  description = "GCS bucket names for imgproxy source images. The Cloud Run SA will be granted roles/storage.objectViewer on each. When non-empty, enables IMGPROXY_USE_GCS (https://docs.imgproxy.net/configuration/options#IMGPROXY_USE_GCS)."
}

variable "cache_bucket" {
  type        = string
  default     = null
  description = "Existing GCS bucket name for imgproxy result cache (imgproxy Pro only). The Cloud Run SA will be granted roles/storage.objectAdmin. Configure cache env vars via var.environment (https://docs.imgproxy.net/configuration/options#IMGPROXY_CACHE_BUCKET)."
}

# ── Scaling ───────────────────────────────────────────────────────────────────

variable "min_instances" {
  type        = number
  default     = 1
  description = "Minimum number of Cloud Run instances (set to 1 to avoid cold starts)."
}

variable "max_instances" {
  type        = number
  default     = 10
  description = "Maximum number of Cloud Run instances."
}

# ── imgproxy Pro ──────────────────────────────────────────────────────────────

variable "pro" {
  type        = bool
  default     = false
  description = "Use imgproxy Pro (docker.imgproxy.pro) instead of the community image (ghcr.io)."
}

variable "pro_registry_password_secret" {
  type = object({
    id      = string
    version = optional(string, "latest")
  })
  default     = null
  description = "Secret Manager secret for the docker.imgproxy.pro registry password. Required when pro = true. Granted to the Artifact Registry Service Agent."
}

variable "pro_license_key_secret" {
  type = object({
    id      = string
    version = optional(string, "latest")
  })
  default     = null
  description = "Secret Manager secret for the imgproxy Pro license key. Sets IMGPROXY_LICENSE_KEY (https://docs.imgproxy.net/configuration/options#IMGPROXY_LICENSE_KEY)."
}

# ── Observability & Monitoring ────────────────────────────────────────────────

variable "enable_monitoring" {
  type        = bool
  default     = false
  description = "Enable the OpenTelemetry collector sidecar to send traces, metrics, and logs to Google Cloud Trace, Cloud Monitoring, and Cloud Logging. Automatically configures imgproxy OTEL environment variables."
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
  description = "OpenTelemetry collector configuration file mounted at /etc/otel/config.yaml when monitoring is enabled. Supports collector environment variable expansion such as $${GOOGLE_CLOUD_PROJECT}."
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "allow_unauthenticated" {
  type        = bool
  default     = true
  description = "Whether to allow unauthenticated (public) requests."
}

variable "ingress" {
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"
  description = "Cloud Run ingress setting. Use INGRESS_TRAFFIC_INTERNAL_ONLY to restrict to VPC."

  validation {
    condition     = contains(["INGRESS_TRAFFIC_ALL", "INGRESS_TRAFFIC_INTERNAL_ONLY", "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"], var.ingress)
    error_message = "Must be one of: INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  }
}

variable "vpc_access" {
  type = object({
    connector = optional(string)
    egress    = optional(string)
    network_interfaces = optional(object({
      network    = optional(string)
      subnetwork = optional(string)
      tags       = optional(list(string))
    }))
  })
  default     = null
  description = "Configure VPC access. Set egress to ALL_TRAFFIC or PRIVATE_RANGES_ONLY. Choose a connector or network_interfaces for direct VPC egress."
}

# ── Cloud CDN ─────────────────────────────────────────────────────────────────

variable "enable_cdn" {
  type        = bool
  default     = false
  description = "Enable Cloud CDN with global HTTPS load balancer. Creates static IP, backend, URL map, and SSL termination."
}

variable "cdn_domains" {
  type        = list(string)
  default     = []
  description = "Domain names for managed SSL certificates (e.g., ['cdn.example.com']). Creates Google-managed certs with auto-renewal. Mutually exclusive with cdn_ssl_certificates."
}

variable "cdn_ssl_certificates" {
  type        = list(string)
  default     = []
  description = "Names of existing SSL certificate resources. For externally managed certificates. Mutually exclusive with cdn_domains."
}

variable "cdn_cache_mode" {
  type        = string
  default     = "CACHE_ALL_STATIC"
  description = "CDN cache mode. Options: CACHE_ALL_STATIC, USE_ORIGIN_HEADERS, FORCE_CACHE_ALL."

  validation {
    condition     = contains(["CACHE_ALL_STATIC", "USE_ORIGIN_HEADERS", "FORCE_CACHE_ALL"], var.cdn_cache_mode)
    error_message = "Must be one of: CACHE_ALL_STATIC, USE_ORIGIN_HEADERS, FORCE_CACHE_ALL."
  }
}

variable "cdn_default_ttl" {
  type        = number
  default     = 2628000
  description = "Default TTL in seconds for cached content when origin doesn't specify Cache-Control."
}

variable "cdn_client_ttl" {
  type        = number
  default     = 3600
  description = "Client (browser) TTL in seconds. Overrides origin Cache-Control for client caching."
}

variable "cdn_max_ttl" {
  type        = number
  default     = 31556926
  description = "Maximum TTL in seconds that CDN will cache content, regardless of origin headers."
}

variable "cdn_negative_caching" {
  type        = bool
  default     = true
  description = "Enable caching of error responses (4xx, 5xx). Reduces backend load for missing images."
}

variable "cdn_serve_while_stale" {
  type        = number
  default     = 86400
  description = "Seconds Cloud CDN will serve stale content while revalidating in the background. 86400 = 24 hours. Prevents thundering-herd latency spikes when many cache entries expire simultaneously. Set to 0 to disable."
}

variable "cdn_log_sample_rate" {
  type        = number
  default     = 0.1
  description = "Fraction of CDN requests to write to Cloud Logging (0.0–1.0). 0.1 = 10%. Higher values increase observability but raise Cloud Logging ingestion costs significantly at scale."
  validation {
    condition     = var.cdn_log_sample_rate >= 0 && var.cdn_log_sample_rate <= 1
    error_message = "cdn_log_sample_rate must be between 0 and 1."
  }
}

variable "cdn_redirect_http_to_https" {
  type        = bool
  default     = true
  description = "Automatically redirect HTTP traffic to HTTPS. Recommended for security."
}

# ── Service Configuration ─────────────────────────────────────────────────────

variable "service_account" {
  type        = string
  default     = null
  description = "Email of an existing service account to attach to the Cloud Run service. When null, a dedicated service account is created automatically."
}

variable "service_labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to the Cloud Run service."
}

variable "template_labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to the Cloud Run revision template."
}

variable "service_scaling" {
  type = object({
    min_instance_count = optional(number)
  })
  default     = null
  description = "Service-level minimum instance count (independent of revision scaling)."
}

variable "traffic" {
  type = list(object({
    type     = optional(string, "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST")
    percent  = optional(number, 100)
    revision = optional(string, null)
    tag      = optional(string, null)
  }))
  default     = []
  description = "Traffic distribution across revisions. Defaults to 100% to the latest ready revision."
}

variable "launch_stage" {
  type        = string
  default     = "GA"
  description = "Cloud Run launch stage. Use BETA to enable beta features. Allowed: ALPHA, BETA, GA."

  validation {
    condition     = contains(["UNIMPLEMENTED", "PRELAUNCH", "EARLY_ACCESS", "ALPHA", "BETA", "GA", "DEPRECATED"], var.launch_stage)
    error_message = "Must be one of: UNIMPLEMENTED, PRELAUNCH, EARLY_ACCESS, ALPHA, BETA, GA, DEPRECATED."
  }
}

variable "service_annotations" {
  type        = map(string)
  default     = {}
  description = "Annotations applied to the Cloud Run service."
}

variable "template_annotations" {
  type        = map(string)
  default     = {}
  description = "Annotations applied to the Cloud Run revision template."
}

variable "revision" {
  type        = string
  default     = null
  description = "Pinned revision name. When omitted, Cloud Run generates a name automatically."
}

variable "custom_audiences" {
  type        = list(string)
  default     = null
  description = "Custom audiences for this service, as full URLs. See https://cloud.google.com/run/docs/configuring/custom-audiences."
}

variable "session_affinity" {
  type        = string
  default     = null
  description = "Enables session affinity. See https://cloud.google.com/run/docs/configuring/session-affinity."
}

variable "encryption_key" {
  type        = string
  default     = null
  description = "Customer-managed encryption key (CMEK) reference to encrypt the container image."
}

variable "binary_authorization" {
  type = object({
    breakglass_justification = optional(string)
    use_default              = optional(bool)
  })
  default     = null
  description = "Binary Authorization settings. use_default enables the project's default policy."
}
