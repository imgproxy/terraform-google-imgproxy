data "google_project" "project" {
  project_id = var.project_id
}

locals {
  # GCP-specific repo IDs (needed for module inputs)
  ghcr_repo_id = "${var.service_name}-ghcr"
  pro_repo_id  = "${var.service_name}-pro"
}

module "imgproxy_common" {
  source = "./modules/common/imgproxy-common"

  # Image config
  tag                    = var.tag
  repo                   = var.repo
  pro                    = var.pro
  pro_repo_default       = "${var.location}-docker.pkg.dev/${var.project_id}/${local.pro_repo_id}/imgproxy"
  community_repo_default = "${var.location}-docker.pkg.dev/${var.project_id}/${local.ghcr_repo_id}/imgproxy/imgproxy"

  # Compute
  cpu            = var.cpu
  workers        = var.workers
  timeout        = var.timeout
  signature_size = var.signature_size

  # Provider-specific
  secret_key_name   = "secret"
  storage_env_key   = "IMGPROXY_USE_GCS"
  storage_enabled   = length(var.source_buckets) > 0
  enable_monitoring = var.enable_monitoring
  otel_service_name = var.service_name

  # Secrets
  insecure                         = var.insecure
  environment                      = var.environment
  secrets                          = var.secrets
  keys_secret                      = var.keys_secret
  salts_secret                     = var.salts_secret
  secret_secret                    = var.secret_secret
  trusted_signatures_secret        = var.trusted_signatures_secret
  source_url_encryption_key_secret = var.source_url_encryption_key_secret
  pro_license_key_secret           = var.pro_license_key_secret
}

locals {
  # From common module
  image             = module.imgproxy_common.image
  workers           = module.imgproxy_common.workers
  env_secret_vars   = module.imgproxy_common.env_secret_vars
  env_vars          = module.imgproxy_common.env_vars
  cdn_cache_headers = module.imgproxy_common.cdn_cache_headers
  cdn_cache_cookies = module.imgproxy_common.cdn_cache_cookies

  # GCP-specific locals
  # Computed from known inputs so the value is available at plan time.
  # Avoids passing google_service_account.imgproxy.email directly to the child
  # module, which would make it unknown during plan and break count expressions
  # inside the upstream module.
  service_account_email = var.service_account != null ? var.service_account : "${var.service_name}-sa@${var.project_id}.iam.gserviceaccount.com"

  cdn_ssl_certs = var.enable_cdn ? (
    length(var.cdn_domains) > 0 ? [google_compute_managed_ssl_certificate.cdn[0].id] :
    [for cert in var.cdn_ssl_certificates : cert]
  ) : []
}

resource "terraform_data" "monitoring_config" {
  input = {
    enabled = var.enable_monitoring
    config  = var.enable_monitoring ? var.otel_collector_config : null
  }
}

# Tracks secret version strings so Terraform triggers a new Cloud Run revision
# when users pin versions explicitly. Does not detect out-of-band secret rotations
# when version = "latest" — those require a manual terraform apply to redeploy.
resource "terraform_data" "secret_config" {
  input = {
    keys    = var.keys_secret
    salts   = var.salts_secret
    secret  = var.secret_secret
    license = var.pro_license_key_secret
    secrets = var.secrets
  }
}

resource "google_project_service" "apis" {
  for_each = toset(concat(
    ["run.googleapis.com", "secretmanager.googleapis.com", "artifactregistry.googleapis.com"],
    var.enable_monitoring ? ["monitoring.googleapis.com", "cloudtrace.googleapis.com", "logging.googleapis.com"] : [],
    (length(var.source_buckets) > 0 || var.cache_bucket != null) ? ["storage.googleapis.com"] : [],
    var.enable_cdn ? ["compute.googleapis.com"] : [],
  ))

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "imgproxy" {
  count        = var.service_account == null ? 1 : 0
  project      = var.project_id
  account_id   = "${var.service_name}-sa"
  display_name = "imgproxy Cloud Run service account"
  depends_on   = [google_project_service.apis]

  lifecycle {
    precondition {
      condition     = !var.pro || var.pro_registry_password_secret != null || var.repo != null
      error_message = "pro_registry_password_secret is required when pro = true and repo is not set."
    }
    precondition {
      condition     = var.insecure || (var.keys_secret != null && var.salts_secret != null)
      error_message = "keys_secret and salts_secret are required when insecure = false."
    }
  }
}

resource "google_project_iam_member" "otel_trace" {
  count      = var.enable_monitoring ? 1 : 0
  project    = var.project_id
  role       = "roles/cloudtrace.agent"
  member     = "serviceAccount:${local.service_account_email}"
  depends_on = [google_service_account.imgproxy]
}

resource "google_project_iam_member" "otel_metrics" {
  count      = var.enable_monitoring ? 1 : 0
  project    = var.project_id
  role       = "roles/monitoring.metricWriter"
  member     = "serviceAccount:${local.service_account_email}"
  depends_on = [google_service_account.imgproxy]
}

resource "google_project_iam_member" "otel_logs" {
  count      = var.enable_monitoring ? 1 : 0
  project    = var.project_id
  role       = "roles/logging.logWriter"
  member     = "serviceAccount:${local.service_account_email}"
  depends_on = [google_service_account.imgproxy]
}

# ── OTEL collector sidecar config ────────────────────────────────────────────

resource "google_secret_manager_secret" "otel_collector_config" {
  count     = var.enable_monitoring ? 1 : 0
  project   = var.project_id
  secret_id = "${var.service_name}-otel-collector-config"
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "otel_collector_config" {
  count       = var.enable_monitoring ? 1 : 0
  secret      = google_secret_manager_secret.otel_collector_config[0].id
  secret_data = var.otel_collector_config
}

# ── Secret Manager IAM ────────────────────────────────────────────────────────

resource "google_secret_manager_secret_iam_member" "cloud_run" {
  for_each   = toset([for k, v in local.env_secret_vars : v.secret])
  secret_id  = each.value
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${local.service_account_email}"
  depends_on = [google_service_account.imgproxy]
}

resource "google_secret_manager_secret_iam_member" "otel_config" {
  count      = var.enable_monitoring ? 1 : 0
  project    = var.project_id
  secret_id  = google_secret_manager_secret.otel_collector_config[0].secret_id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${local.service_account_email}"
  depends_on = [google_service_account.imgproxy]
}

# The Artifact Registry Service Agent reads this secret to authenticate upstream.
resource "google_secret_manager_secret_iam_member" "artifact_registry" {
  count      = var.pro && var.pro_registry_password_secret != null ? 1 : 0
  secret_id  = var.pro_registry_password_secret.id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"
  depends_on = [google_project_service.apis]
}

# ── Cloud Run service ─────────────────────────────────────────────────────────

resource "google_cloud_run_v2_service" "main" {
  project  = var.project_id
  location = var.location
  name     = var.service_name

  description         = var.description
  ingress             = var.enable_cdn ? "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" : var.ingress
  launch_stage        = var.launch_stage
  labels              = var.service_labels
  annotations         = var.service_annotations
  custom_audiences    = var.custom_audiences
  deletion_protection = var.deletion_protection
  dynamic "binary_authorization" {
    for_each = var.binary_authorization != null ? [var.binary_authorization] : []
    content {
      use_default              = binary_authorization.value.use_default
      breakglass_justification = binary_authorization.value.breakglass_justification
    }
  }

  dynamic "scaling" {
    for_each = var.service_scaling != null ? [var.service_scaling] : []
    content {
      min_instance_count = scaling.value.min_instance_count
    }
  }

  template {
    service_account = local.service_account_email
    revision        = var.revision
    labels          = var.template_labels
    annotations     = var.template_annotations
    timeout         = var.timeout != null ? "${var.timeout}s" : null

    execution_environment            = var.execution_environment
    max_instance_request_concurrency = local.workers
    session_affinity                 = var.session_affinity
    encryption_key                   = var.encryption_key

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    dynamic "vpc_access" {
      for_each = var.vpc_access != null ? [var.vpc_access] : []
      content {
        connector = vpc_access.value.connector
        egress    = vpc_access.value.egress
        dynamic "network_interfaces" {
          for_each = vpc_access.value.network_interfaces != null ? [vpc_access.value.network_interfaces] : []
          content {
            network    = network_interfaces.value.network
            subnetwork = network_interfaces.value.subnetwork
            tags       = network_interfaces.value.tags
          }
        }
      }
    }

    # Main container
    containers {
      name    = "imgproxy"
      image   = local.image
      command = null
      args    = null

      ports {
        name           = "http1"
        container_port = 8080
      }

      dynamic "env" {
        for_each = local.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.env_secret_vars
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret
              version = env.value.version
            }
          }
        }
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle          = var.cpu_idle
        startup_cpu_boost = false
      }

      startup_probe {
        initial_delay_seconds = 2
        period_seconds        = 2
        failure_threshold     = 30
        http_get {
          path = "/health"
          port = 8080
        }
      }

      liveness_probe {
        period_seconds    = 10
        failure_threshold = 5
        http_get {
          path = "/health"
          port = 8080
        }
      }
    }

    # OpenTelemetry collector sidecar (conditional)
    # Receives OTLP data from imgproxy and forwards to Cloud Trace/Cloud Monitoring
    dynamic "containers" {
      for_each = var.enable_monitoring ? [1] : []
      content {
        name    = "otel-collector"
        image   = "otel/opentelemetry-collector-contrib:0.111.0"
        command = null
        args    = ["--config=/etc/otel/config.yaml"]

        # OTEL collector configuration via environment
        env {
          name  = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }

        volume_mounts {
          name       = "otel-collector-config"
          mount_path = "/etc/otel"
        }

        resources {
          limits = {
            cpu    = "1000m"
            memory = "256Mi"
          }
          cpu_idle          = true
          startup_cpu_boost = false
        }
      }
    }

    # Volume for OTEL collector config
    dynamic "volumes" {
      for_each = var.enable_monitoring ? [1] : []
      content {
        name = "otel-collector-config"
        secret {
          secret = google_secret_manager_secret.otel_collector_config[0].secret_id
          items {
            path    = "config.yaml"
            version = "latest"
          }
        }
      }
    }
  }

  dynamic "traffic" {
    for_each = length(var.traffic) > 0 ? var.traffic : [{ type = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST", percent = 100, revision = null, tag = null }]
    content {
      type     = traffic.value.type
      percent  = traffic.value.percent
      revision = traffic.value.revision
      tag      = traffic.value.tag
    }
  }

  lifecycle {
    precondition {
      condition     = !var.enable_cdn || var.secret_secret == null
      error_message = "secret_secret cannot be used with enable_cdn = true. The CDN does not forward the Authorization header."
    }

    precondition {
      condition     = !var.enable_cdn || length(var.cdn_domains) > 0 || length(var.cdn_ssl_certificates) > 0
      error_message = "When enable_cdn = true, either cdn_domains or cdn_ssl_certificates must be provided."
    }

    precondition {
      condition     = length(var.cdn_domains) == 0 || length(var.cdn_ssl_certificates) == 0
      error_message = "cdn_domains and cdn_ssl_certificates are mutually exclusive."
    }

    precondition {
      condition     = !var.enable_cdn || var.ingress == "INGRESS_TRAFFIC_ALL" || var.ingress == "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
      error_message = "When enable_cdn = true, ingress must be INGRESS_TRAFFIC_ALL or INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER. INGRESS_TRAFFIC_INTERNAL_ONLY blocks Cloud CDN traffic."
    }

    precondition {
      condition     = var.vpc_access == null || var.vpc_access.connector == null || var.vpc_access.network_interfaces == null
      error_message = "vpc_access.connector and vpc_access.network_interfaces are mutually exclusive. Use a VPC connector OR direct VPC egress (network_interfaces), not both."
    }

    replace_triggered_by = [
      terraform_data.monitoring_config,
      terraform_data.secret_config,
    ]
  }

  depends_on = [
    google_service_account.imgproxy,
    google_project_iam_member.otel_trace,
    google_project_iam_member.otel_metrics,
    google_project_iam_member.otel_logs,
    google_secret_manager_secret_iam_member.cloud_run,
    google_secret_manager_secret_iam_member.otel_config,
    google_storage_bucket_iam_member.source,
    google_storage_bucket_iam_member.cache,
    google_artifact_registry_repository.ghcr,
    google_artifact_registry_repository.pro,
  ]
}

# IAM for unauthenticated access
resource "google_cloud_run_v2_service_iam_member" "public" {
  count    = var.allow_unauthenticated ? 1 : 0
  project  = google_cloud_run_v2_service.main.project
  location = google_cloud_run_v2_service.main.location
  name     = google_cloud_run_v2_service.main.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ── GCS bucket IAM ───────────────────────────────────────────────────────────

resource "google_storage_bucket_iam_member" "source" {
  for_each   = toset(var.source_buckets)
  bucket     = each.value
  role       = "roles/storage.objectViewer"
  member     = "serviceAccount:${local.service_account_email}"
  depends_on = [google_service_account.imgproxy]
}

resource "google_storage_bucket_iam_member" "cache" {
  count      = var.cache_bucket != null ? 1 : 0
  bucket     = var.cache_bucket
  role       = "roles/storage.objectAdmin"
  member     = "serviceAccount:${local.service_account_email}"
  depends_on = [google_service_account.imgproxy]
}

# ── Artifact Registry remote repositories ────────────────────────────────────
# Cloud Run only allows images from gcr.io, pkg.dev, and docker.io.
# Remote repos proxy the upstream registries and cache images in AR.
# Cloud Run's service agent has reader access to all repos in the same project
# by default, so no extra IAM is needed for image pulls.

resource "google_artifact_registry_repository" "ghcr" {
  count         = var.repo == null && !var.pro ? 1 : 0
  project       = var.project_id
  repository_id = local.ghcr_repo_id
  location      = var.location
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"

  remote_repository_config {
    description = "ghcr.io proxy"
    docker_repository {
      custom_repository {
        uri = "https://ghcr.io"
      }
    }
  }

  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "delete-old-cached"
    action = "DELETE"
    condition {
      older_than = "2592000s" # 30 days
    }
  }

  depends_on = [google_project_service.apis, google_service_account.imgproxy]
}

# ── Pro registry (docker.imgproxy.pro) ────────────────────────────────────────

resource "google_artifact_registry_repository" "pro" {
  count         = var.repo == null && var.pro ? 1 : 0
  project       = var.project_id
  repository_id = local.pro_repo_id
  location      = var.location
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"

  remote_repository_config {
    description = "docker.imgproxy.pro proxy"
    docker_repository {
      custom_repository {
        uri = "https://docker.imgproxy.pro"
      }
    }
    upstream_credentials {
      username_password_credentials {
        username                = "imgproxy"
        password_secret_version = "${var.pro_registry_password_secret.id}/versions/${var.pro_registry_password_secret.version}"
      }
    }
  }

  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "delete-old-cached"
    action = "DELETE"
    condition {
      older_than = "2592000s" # 30 days
    }
  }

  lifecycle {
    precondition {
      condition     = var.pro_registry_password_secret != null
      error_message = "pro_registry_password_secret is required when pro = true."
    }
  }

  depends_on = [
    google_project_service.apis,
    google_secret_manager_secret_iam_member.artifact_registry,
  ]
}

# ── Cloud CDN ─────────────────────────────────────────────────────────────────
# Global HTTPS load balancer with Cloud CDN for caching processed images at edge
# locations worldwide. Creates static IP, serverless NEG, backend service with
# CDN policy, URL map, target proxy, and SSL termination.

resource "google_compute_global_address" "cdn" {
  count      = var.enable_cdn ? 1 : 0
  project    = var.project_id
  name       = "${var.service_name}-cdn-ip"
  ip_version = "IPV4"
  depends_on = [google_project_service.apis]
}

resource "google_compute_region_network_endpoint_group" "cdn" {
  count                 = var.enable_cdn ? 1 : 0
  project               = var.project_id
  name                  = "${var.service_name}-neg"
  region                = var.location
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.main.name
  }

  depends_on = [google_cloud_run_v2_service.main]
}

resource "google_compute_backend_service" "cdn" {
  count                 = var.enable_cdn ? 1 : 0
  project               = var.project_id
  name                  = "${var.service_name}-backend"
  protocol              = "HTTPS"
  port_name             = "http"
  timeout_sec           = var.timeout != null ? var.timeout : 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.cdn[0].id
  }

  cdn_policy {
    cache_mode        = var.cdn_cache_mode
    default_ttl       = var.cdn_default_ttl
    max_ttl           = var.cdn_max_ttl
    client_ttl        = var.cdn_client_ttl
    negative_caching  = var.cdn_negative_caching
    serve_while_stale = var.cdn_serve_while_stale

    cache_key_policy {
      include_host          = true
      include_protocol      = true
      include_query_string  = false
      include_http_headers  = local.cdn_cache_headers
      include_named_cookies = local.cdn_cache_cookies
    }
  }

  log_config {
    enable      = true
    sample_rate = var.cdn_log_sample_rate
  }
  depends_on = [google_project_service.apis]
}

resource "google_compute_managed_ssl_certificate" "cdn" {
  count   = var.enable_cdn && length(var.cdn_domains) > 0 ? 1 : 0
  project = var.project_id
  name    = "${var.service_name}-cert"

  managed {
    domains = var.cdn_domains
  }

  depends_on = [google_project_service.apis]
}

resource "google_compute_url_map" "cdn" {
  count           = var.enable_cdn ? 1 : 0
  project         = var.project_id
  name            = "${var.service_name}-lb"
  default_service = google_compute_backend_service.cdn[0].id

  depends_on = [google_project_service.apis, google_compute_backend_service.cdn]
}

resource "google_compute_url_map" "cdn_http_redirect" {
  count   = var.enable_cdn && var.cdn_redirect_http_to_https ? 1 : 0
  project = var.project_id
  name    = "${var.service_name}-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }

  depends_on = [google_project_service.apis]
}

resource "google_compute_target_http_proxy" "cdn_redirect" {
  count   = var.enable_cdn && var.cdn_redirect_http_to_https ? 1 : 0
  project = var.project_id
  name    = "${var.service_name}-http-proxy"
  url_map = google_compute_url_map.cdn_http_redirect[0].id

  depends_on = [google_project_service.apis, google_compute_url_map.cdn_http_redirect]
}

# HTTP proxy for direct backend access (when redirect disabled)
resource "google_compute_target_http_proxy" "cdn_http" {
  count   = var.enable_cdn && !var.cdn_redirect_http_to_https ? 1 : 0
  project = var.project_id
  name    = "${var.service_name}-http-proxy"
  url_map = google_compute_url_map.cdn[0].id

  depends_on = [google_project_service.apis, google_compute_url_map.cdn]
}

resource "google_compute_global_forwarding_rule" "cdn_http" {
  count                 = var.enable_cdn ? 1 : 0
  project               = var.project_id
  name                  = "${var.service_name}-http-rule"
  target                = var.cdn_redirect_http_to_https ? google_compute_target_http_proxy.cdn_redirect[0].id : google_compute_target_http_proxy.cdn_http[0].id
  port_range            = "80"
  ip_address            = google_compute_global_address.cdn[0].address
  load_balancing_scheme = "EXTERNAL_MANAGED"

  depends_on = [
    google_project_service.apis,
    google_compute_target_http_proxy.cdn_redirect,
    google_compute_target_http_proxy.cdn_http,
  ]
}

resource "google_compute_target_https_proxy" "cdn" {
  count            = var.enable_cdn ? 1 : 0
  project          = var.project_id
  name             = "${var.service_name}-https-proxy"
  url_map          = google_compute_url_map.cdn[0].id
  ssl_certificates = local.cdn_ssl_certs

  depends_on = [google_project_service.apis, google_compute_url_map.cdn]
}

resource "google_compute_global_forwarding_rule" "cdn" {
  count                 = var.enable_cdn ? 1 : 0
  project               = var.project_id
  name                  = "${var.service_name}-https-rule"
  target                = google_compute_target_https_proxy.cdn[0].id
  port_range            = "443"
  ip_address            = google_compute_global_address.cdn[0].address
  load_balancing_scheme = "EXTERNAL_MANAGED"

  depends_on = [google_project_service.apis, google_compute_target_https_proxy.cdn]
}
