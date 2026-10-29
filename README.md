# imgproxy Terraform Module for Google Cloud Run

Terraform module to deploy [imgproxy](https://imgproxy.net/) on Google Cloud Run with optional Cloud CDN, OpenTelemetry-based monitoring, and GCS integration.

## Features

- **Cloud Run v2 deployment** with configurable CPU, memory, and scaling
- **Cloud CDN integration** with global HTTPS load balancer for caching and low-latency access worldwide
- **imgproxy Pro support** via Artifact Registry remote repository with authentication
- **OpenTelemetry collector sidecar** for traces, metrics, and logs to Cloud Trace, Cloud Monitoring, and Cloud Logging
- **GCS bucket integration** for source images and result cache (Pro)
- **Request signing** with configurable keys and salts
- **Secret Manager integration** for all sensitive configuration
- **Artifact Registry remote repositories** for transparent image caching from ghcr.io and docker.imgproxy.pro
- **VPC access** support for private network egress
- **Flexible configuration** via environment variables

## Prerequisites

Before using this module, ensure you have:

- **A Google Cloud account and project** - [Create a project](https://console.cloud.google.com/projectcreate) if you don't have one
- **Google Cloud SDK** - [Install gcloud CLI](https://cloud.google.com/sdk/docs/install) and authenticate:
  ```bash
  gcloud auth application-default login
  gcloud config set project YOUR_PROJECT_ID
  ```
- **Terraform** - [Install Terraform](https://developer.hashicorp.com/terraform/install) (version 1.5 or later)

## Getting Started

### Create a Terraform Directory

Create a new directory for your imgproxy deployment:

```bash
mkdir terraform-gcs
cd terraform-gcs
```

Create a `main.tf` file with your module configuration (see examples below).

### Initialize and Deploy

```bash
# Download providers and modules
terraform init

# Preview changes
terraform plan

# Deploy to Google Cloud
terraform apply
```

## Usage Examples

Examples are ordered from simplest to most advanced. Start with the example that matches your use case.

### 1. Development Setup (Insecure Mode)

**⚠️ WARNING:** This configuration disables request signing. Use only for local development and testing. **Never use in production!**

**What you get:** Basic imgproxy deployment with no authentication, no monitoring, minimal resources.

**Create `main.tf`:**
```hcl
module "imgproxy" {
  source = "github.com/imgproxy/terraform-gcs"

  project_id   = "my-project"
  service_name = "imgproxy-dev"

  # WARNING: No request signing - development only!
  insecure = true
}

output "url" {
  value = module.imgproxy.url
}
```

**Deploy and test:**
```bash
terraform init
terraform apply

# Get the URL
URL=$(terraform output -raw url)

# Test (no signature required in insecure mode!)
curl "$URL/health"
curl -I "$URL/insecure/plain/https://picsum.photos/200"
```

**When to use:** Quick testing, local development, proof of concept.

---

### 2. Production Setup with URL Signing

**What you get:** Secure imgproxy with request signing to prevent unauthorized image processing.

**First, create signing keys and store them in Secret Manager:**

```bash
# Generate random signing keys and store directly in Secret Manager
openssl rand -hex 64 | gcloud secrets create imgproxy-keys --data-file=-
openssl rand -hex 64 | gcloud secrets create imgproxy-salts --data-file=-
```

**Create `main.tf`:**
```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

module "imgproxy" {
  source = "github.com/imgproxy/terraform-gcs"

  project_id   = var.project_id
  service_name = "imgproxy"

  # Security: request signing (required for production)
  # Reference project_id variable to avoid hardcoding
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
```

**Create `terraform.tfvars`:**
```hcl
project_id = "my-project"
```

**Deploy and test with signed URLs:**
```bash
terraform init
terraform apply

# Get the URL
URL=$(terraform output -raw url)

# Unsigned requests are now rejected
curl "$URL/insecure/plain/https://picsum.photos/200"
# Returns: 403 Forbidden

# You need to generate signed URLs using imgproxy's signing algorithm
# See: https://docs.imgproxy.net/usage/signing_the_url
```

**When to use:** Production deployments, any public-facing service.

---

### 3. imgproxy with GCS Bucket

**What you get:** imgproxy that reads source images directly from a private GCS bucket using the `gs://` URL scheme, so your originals are never exposed publicly.

**Create `main.tf`:**
```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

resource "google_storage_bucket" "images" {
  name                        = "my-project-images"
  location                    = "us-central1"
  uniform_bucket_level_access = true
}

module "imgproxy" {
  source = "github.com/imgproxy/terraform-gcs"

  project_id   = var.project_id
  service_name = "imgproxy"

  keys_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-keys"
  }
  salts_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-salts"
  }

  # Grant imgproxy read access to the bucket and enable gs:// URL scheme
  source_buckets = [google_storage_bucket.images.name]
}

output "url" {
  value = module.imgproxy.url
}
```

**Create `terraform.tfvars`:**
```hcl
project_id = "my-project"
```

**Deploy and process images from GCS:**
```bash
terraform init
terraform apply

# Upload a test image
gcloud storage cp photo.jpg gs://my-project-images/photo.jpg

URL=$(terraform output -raw url)

# Unsigned requests are rejected (security is enabled)
curl "$URL/insecure/plain/gs://my-project-images/photo.jpg"
# Returns: 403 Forbidden

# Generate signed URLs using imgproxy's signing algorithm
# See: https://docs.imgproxy.net/usage/signing_the_url
# Example with proper signature:
# curl "$URL/<signature>/rs:fit:300:200/plain/gs://my-project-images/photo.jpg"
```

The module grants `roles/storage.objectViewer` to the imgproxy service account automatically — the bucket stays private.

**When to use:** When your source images are stored in GCS and should not be publicly accessible.

---

### 4. imgproxy Pro with License Key

**What you get:** imgproxy Pro edition with advanced features like result caching, video processing, and more.

**First, create secrets for Pro license and registry password:**

```bash
# Store your Pro license key
echo -n "your-license-key-here" | gcloud secrets create imgproxy-pro-license --data-file=-

# Store your docker.imgproxy.pro registry password
echo -n "your-registry-password" | gcloud secrets create imgproxy-pro-password --data-file=-

# Also create signing keys (same as previous example)
openssl rand -hex 64 | gcloud secrets create imgproxy-keys --data-file=-
openssl rand -hex 64 | gcloud secrets create imgproxy-salts --data-file=-
```

**Create `main.tf`:**
```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

resource "google_storage_bucket" "source" {
  name                        = "${var.project_id}-imgproxy-source"
  location                    = "us-central1"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "cache" {
  name                        = "${var.project_id}-imgproxy-cache"
  location                    = "us-central1"
  uniform_bucket_level_access = true
}

module "imgproxy" {
  source = "github.com/imgproxy/terraform-gcs"

  project_id   = var.project_id
  service_name = "imgproxy-pro"
  tag          = "v4.0"  # Specify Pro version

  # Enable Pro edition
  pro                          = true
  pro_registry_password_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-pro-password"
  }
  pro_license_key_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-pro-license"
  }

  # Security (required)
  keys_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-keys"
  }
  salts_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-salts"
  }

  # GCS buckets for source images and result caching
  source_buckets = [google_storage_bucket.source.name]  # Images to process
  cache_bucket   = google_storage_bucket.cache.name     # Processed results (Pro feature)

  environment = {
    IMGPROXY_CACHE_USE    = "gcs"
    IMGPROXY_CACHE_BUCKET = google_storage_bucket.cache.name
  }
}

output "url" {
  value = module.imgproxy.url
}
```

**Create `terraform.tfvars`:**
```hcl
project_id = "my-project"
```

**Deploy:**
```bash
terraform init
terraform apply
```

**Using GCS buckets:**

When `source_buckets` is set, you can process images directly from GCS using the `gs://` scheme:
```bash
# Unsigned requests are rejected
curl "https://your-service/insecure/plain/gs://my-project-imgproxy-source/photo.jpg"
# Returns: 403 Forbidden

# Generate signed URLs - see https://docs.imgproxy.net/usage/signing_the_url
# Example with signature:
# curl "https://your-service/<signature>/plain/gs://my-project-imgproxy-source/photo.jpg"
```

When `cache_bucket` is set (Pro only), imgproxy caches processed results in GCS for faster subsequent requests.

**When to use:** When you need Pro features like caching, video processing, advanced image formats, or GCS integration.

---

### 5. Custom Image Override

**What you get:** Ability to use a custom imgproxy image from any registry instead of the default.

**Use cases:**
- Custom imgproxy build with additional features
- Private fork with company-specific modifications
- Mirror from a different registry (GCR, Artifact Registry, Docker Hub, etc.)

**Create `main.tf`:**
```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

module "imgproxy" {
  source = "github.com/imgproxy/terraform-gcs"

  project_id   = var.project_id
  service_name = "imgproxy-custom"

  # Override the default repository with your custom one (tag is set separately)
  repo = "gcr.io/my-project/custom-imgproxy"
  tag  = "v1.0.0"

  # Security
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
```

**Create `terraform.tfvars`:**
```hcl
project_id = "my-project"
```

**Note:** When `repo` is set, the module skips creating Artifact Registry remote repositories since you're providing the repository directly. Use `tag` to specify the version (supports both regular tags and `sha256:...` digests).

#### Setting Up Your Own Mirror in Artifact Registry

If you want to mirror imgproxy images in your own Artifact Registry:

```bash
# Create an Artifact Registry repository
gcloud artifacts repositories create imgproxy-mirror \
  --repository-format=docker \
  --location=us-central1 \
  --description="imgproxy mirror"

# Pull the official image
docker pull darthsim/imgproxy:v3.0

# Tag for your registry
docker tag darthsim/imgproxy:v3.0 \
  us-central1-docker.pkg.dev/my-project/imgproxy-mirror/imgproxy:v3.0

# Push to your registry
docker push us-central1-docker.pkg.dev/my-project/imgproxy-mirror/imgproxy:v3.0
```

Then use in Terraform:
```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

module "imgproxy" {
  source = "github.com/imgproxy/terraform-gcs"

  project_id   = var.project_id
  service_name = "imgproxy"

  # Use your mirrored repository
  repo = "us-central1-docker.pkg.dev/${var.project_id}/imgproxy-mirror/imgproxy"
  tag  = "v3.0"

  keys_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-keys"
  }
  salts_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-salts"
  }
}
```

**When to use:** Custom builds, compliance requirements for image scanning, air-gapped environments, private forks.

---

### 6. Cloud CDN for Global Low-Latency Access

**What you get:** Global HTTPS load balancer with Cloud CDN caching processed images at edge locations worldwide.

**Important:** You need a domain name to use Cloud CDN (for SSL certificates).

**Create `main.tf`:**
```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

module "imgproxy" {
  source = "github.com/imgproxy/terraform-gcs"

  project_id   = var.project_id
  service_name = "imgproxy"

  # Security
  keys_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-keys"
  }
  salts_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-salts"
  }

  # Cloud CDN configuration
  enable_cdn  = true
  cdn_domains = ["cdn.example.com"]  # Your domain for managed SSL certificate

  # CDN caching settings
  cdn_cache_mode   = "CACHE_ALL_STATIC"  # Cache based on file extensions (recommended)
  cdn_default_ttl  = 3600                # 1 hour default cache
  cdn_max_ttl      = 86400               # 24 hour maximum cache
  cdn_client_ttl   = 3600                # 1 hour browser cache

  # HTTP to HTTPS redirect (recommended for production)
  cdn_redirect_http_to_https = true

  # For testing without HTTPS, you can disable redirect:
  # cdn_redirect_http_to_https = false  # ⚠️ Insecure - HTTP only
}

output "cdn_ip" {
  value       = module.imgproxy.cdn_ip_address
  description = "Point your DNS A record to this IP"
}

output "cert_status" {
  value       = module.imgproxy.cdn_managed_certificate_id
  description = "SSL certificate ID - check status in Cloud Console"
}
```

**Create `terraform.tfvars`:**
```hcl
project_id = "my-project"
```

**Deploy and configure DNS:**
```bash
terraform init
terraform apply

# Get the CDN static IP
terraform output cdn_ip
# Example output: 8.232.52.166

# Point your DNS A record to this IP
# Example DNS record:
# cdn.example.com.  A  8.232.52.166
```

**SSL Certificate Provisioning:**

After pointing your DNS to the CDN IP, Google will automatically provision a managed SSL certificate. This takes **10-60 minutes**.

**Check certificate status:**
```bash
# In Cloud Console: Load Balancing → Certificates
# Or check the certificate ID from terraform output
```

**Testing:**

```bash
# Once certificate is ACTIVE:
curl -I https://cdn.example.com/health

# Test image processing with CDN
curl -I "https://cdn.example.com/signed-url-here"

# Check CDN headers
# First request: X-Cache: MISS
# Second request: X-Cache: HIT (cached!)
```

**CDN Redirect Modes:**

- **`cdn_redirect_http_to_https = true`** (default): HTTP requests redirect to HTTPS. Secure and recommended for production.
- **`cdn_redirect_http_to_https = false`**: HTTP requests go directly to backend. Only use for testing when you don't have a valid domain/certificate.

**SSL Certificate Options:**

1. **Managed certificates** (recommended):
   ```hcl
   cdn_domains = ["cdn.example.com", "images.example.com"]
   ```
   - Google provisions and auto-renews certificates
   - Requires DNS validation (point A record to CDN IP)
   - Free

2. **Existing certificates**:
   ```hcl
   cdn_ssl_certificates = [
     "projects/my-project/global/sslCertificates/my-cert"
   ]
   ```
   - Use pre-existing SSL certificates
   - For custom CA or externally managed certificates

**Important:** When CDN is enabled, direct access to the Cloud Run URL is automatically blocked (`ingress = INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`). All traffic must go through the CDN.

---

## Additional Secrets

The `secrets` variable allows you to pass additional secret environment variables beyond the core imgproxy secrets (keys, salts, license). This is useful for third-party integrations like monitoring, error tracking, or observability tools.

Each entry in the map creates an environment variable with its value pulled from Secret Manager:

```hcl
module "imgproxy" {
  source = "github.com/imgproxy/terraform-gcs"

  project_id   = var.project_id
  service_name = "imgproxy"

  # Core secrets
  keys_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-keys"
  }
  salts_secret = {
    id = "projects/${var.project_id}/secrets/imgproxy-salts"
  }

  # Additional integrations via secrets map
  secrets = {
    IMGPROXY_NEW_RELIC_KEY             = { id = "projects/${var.project_id}/secrets/newrelic-license" }
    IMGPROXY_BUGSNAG_KEY               = { id = "projects/${var.project_id}/secrets/bugsnag-api-key" }
    IMGPROXY_SENTRY_DSN                = { id = "projects/${var.project_id}/secrets/sentry-dsn" }
    IMGPROXY_OPENTELEMETRY_CLIENT_CERT = { id = "projects/${var.project_id}/secrets/otel-client-cert", version = "3" }
  }
}
```

Create the secrets in Secret Manager:
```bash
echo -n "your-newrelic-license" | gcloud secrets create newrelic-license --data-file=-
echo -n "your-bugsnag-key" | gcloud secrets create bugsnag-api-key --data-file=-
```

The environment variable names should match [imgproxy's configuration](https://docs.imgproxy.net/configuration) for your integration.

---

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| google | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| google | ~> 6.0 |

## Inputs

### Core Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID | `string` | n/a | yes |
| location | GCP location for all resources | `string` | `"us-central1"` | no |
| service_name | Prefix applied to every resource name | `string` | `"imgproxy"` | no |
| description | Cloud Run service description (512 char limit) | `string` | `null` | no |
| tag | imgproxy image tag or digest (e.g. `v4`, `sha256:...`) | `string` | `"v4"` | no |
| repo | Custom container repository, overrides the default. Combined with `tag` to form the full image reference | `string` | `null` | no |
| pro | Use imgproxy Pro instead of community image | `bool` | `false` | no |
| deletion_protection | Enable Terraform deletion protection on the Cloud Run service | `bool` | `false` | no |

### Security & Signing

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| insecure | Disable URL signature checks (development only) | `bool` | `false` | no |
| keys_secret | Secret Manager secret containing signing keys ([`IMGPROXY_KEY`](https://docs.imgproxy.net/configuration/options#IMGPROXY_KEY)) | `object({ id = string, version = optional(string) })` | `null` | yes (unless insecure) |
| salts_secret | Secret Manager secret containing signing salts ([`IMGPROXY_SALT`](https://docs.imgproxy.net/configuration/options#IMGPROXY_SALT)) | `object({ id = string, version = optional(string) })` | `null` | yes (unless insecure) |
| signature_size | Number of bytes from key/salt used for signing ([`IMGPROXY_SIGNATURE_SIZE`](https://docs.imgproxy.net/configuration/options#IMGPROXY_SIGNATURE_SIZE)) | `number` | `32` | no |
| secret_secret | Secret Manager secret for authorization token ([`IMGPROXY_SECRET`](https://docs.imgproxy.net/configuration/options#IMGPROXY_SECRET)). Cannot be used with `enable_cdn = true` | `object({ id = string, version = optional(string) })` | `null` | no |
| trusted_signatures_secret | Secret Manager secret for trusted signature prefixes ([`IMGPROXY_TRUSTED_SIGNATURES`](https://docs.imgproxy.net/configuration/options#IMGPROXY_TRUSTED_SIGNATURES)) (Pro only) | `object({ id = string, version = optional(string) })` | `null` | no |
| source_url_encryption_key_secret | Secret Manager secret for source URL encryption key ([`IMGPROXY_SOURCE_URL_ENCRYPTION_KEY`](https://docs.imgproxy.net/configuration/options#IMGPROXY_SOURCE_URL_ENCRYPTION_KEY)) | `object({ id = string, version = optional(string) })` | `null` | no |

### imgproxy Pro Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| pro_registry_password_secret | Secret Manager secret for registry password | `object({ id = string, version = optional(string) })` | `null` | yes (if pro = true) |
| pro_license_key_secret | Secret Manager secret for Pro license key ([`IMGPROXY_LICENSE_KEY`](https://docs.imgproxy.net/configuration/options#IMGPROXY_LICENSE_KEY)) | `object({ id = string, version = optional(string) })` | `null` | no |

### Observability & Monitoring

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| enable_monitoring | Enable the OpenTelemetry collector sidecar to send traces, metrics, and logs to Google Cloud Trace, Cloud Monitoring, and Cloud Logging. Automatically configures imgproxy OTEL environment variables. | `bool` | `false` | no |
| otel_collector_config | OpenTelemetry collector config mounted at `/etc/otel/config.yaml` when monitoring is enabled. Supports collector environment variable expansion such as `$${GOOGLE_CLOUD_PROJECT}`. | `string` | built-in OTLP to Google Cloud config | no |

### Storage Integration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| source_buckets | GCS bucket names for source images. Grants `objectViewer` on each. Enables [`IMGPROXY_USE_GCS`](https://docs.imgproxy.net/configuration/options#IMGPROXY_USE_GCS) | `list(string)` | `[]` | no |
| cache_bucket | Existing GCS bucket name for result cache (Pro only). See [cache options](https://docs.imgproxy.net/configuration/options#cache) | `string` | `null` | no |

### Compute Resources

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cpu | CPU limit for the container | `number` | `1` | no |
| memory | Memory limit for the container | `string` | `"1024Mi"` | no |
| cpu_idle | Throttle CPU when idle. Set to `false` to keep CPU always allocated | `bool` | `true` | no |
| workers | Number of concurrent requests per instance ([`IMGPROXY_WORKERS`](https://docs.imgproxy.net/configuration/options#IMGPROXY_WORKERS)) | `number` | `null` | no |
| timeout | Request timeout in seconds. When set, also configures [`IMGPROXY_TIMEOUT`](https://docs.imgproxy.net/configuration/options#IMGPROXY_TIMEOUT) and CDN backend `timeout_sec`. | `number` | `null` | no |
| execution_environment | Sandbox environment (GEN1 or GEN2) | `string` | `"EXECUTION_ENVIRONMENT_GEN2"` | no |

### Scaling & Networking

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| min_instances | Minimum number of Cloud Run instances | `number` | `1` | no |
| max_instances | Maximum number of Cloud Run instances | `number` | `10` | no |
| ingress | Cloud Run ingress setting | `string` | `"INGRESS_TRAFFIC_ALL"` | no |
| allow_unauthenticated | Allow unauthenticated (public) requests | `bool` | `true` | no |
| vpc_access | VPC access configuration | `object` | `null` | no |

### Cloud CDN

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| enable_cdn | Enable Cloud CDN with global HTTPS load balancer | `bool` | `false` | no |
| cdn_domains | Domain names for managed SSL certificates (e.g., `["cdn.example.com"]`) | `list(string)` | `[]` | yes (if enable_cdn) |
| cdn_ssl_certificates | Names of existing SSL certificate resources (mutually exclusive with cdn_domains) | `list(string)` | `[]` | no |
| cdn_cache_mode | CDN cache mode (CACHE_ALL_STATIC, USE_ORIGIN_HEADERS, FORCE_CACHE_ALL) | `string` | `"CACHE_ALL_STATIC"` | no |
| cdn_default_ttl | Default TTL in seconds for cached content | `number` | `2628000` | no |
| cdn_max_ttl | Maximum TTL in seconds that CDN will cache content | `number` | `31556926` | no |
| cdn_client_ttl | Client (browser) TTL in seconds | `number` | `3600` | no |
| cdn_negative_caching | Enable caching of error responses (4xx, 5xx) | `bool` | `true` | no |
| cdn_redirect_http_to_https | Automatically redirect HTTP traffic to HTTPS | `bool` | `true` | no |

**Note:** When CDN is enabled, Cloud Run ingress is automatically set to `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` to ensure all traffic goes through the CDN.

### Service Configuration

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| service_account | Email of existing service account (creates one if null) | `string` | `null` | no |
| service_labels | Labels applied to the Cloud Run service | `map(string)` | `{}` | no |
| service_annotations | Annotations applied to the Cloud Run service | `map(string)` | `{}` | no |
| template_labels | Labels applied to the Cloud Run revision template | `map(string)` | `{}` | no |
| template_annotations | Annotations applied to the Cloud Run revision template | `map(string)` | `{}` | no |
| revision | Pinned revision name (auto-generated if null) | `string` | `null` | no |
| session_affinity | Enable session affinity | `string` | `null` | no |
| encryption_key | CMEK reference to encrypt the container image | `string` | `null` | no |
| binary_authorization | Binary Authorization settings | `object` | `null` | no |
| launch_stage | Cloud Run launch stage (ALPHA, BETA, GA) | `string` | `"GA"` | no |
| custom_audiences | Custom audiences for this service (full URLs) | `list(string)` | `null` | no |
| traffic | Traffic distribution across revisions | `list(object)` | `[]` | no |
| service_scaling | Service-level minimum instance count | `object` | `null` | no |
| environment | Additional environment variables for imgproxy | `map(string)` | `{}` | no |
| secrets | Additional Secret Manager secrets mapped to env vars | `map(object({ id = string, version = optional(string) }))` | `{}` | no |

See [variables.tf](variables.tf) for complete details and validation rules.

## Outputs

| Name | Description |
|------|-------------|
| url | The URL of the imgproxy Cloud Run service |
| service_name | The Cloud Run service name |
| service_account_email | Email of the imgproxy service account |
| location | The region where the Cloud Run service is deployed |
| cdn_ip_address | Static IP address of the CDN load balancer (when CDN enabled) |
| cdn_managed_certificate_id | ID of the managed SSL certificate (when CDN enabled with managed cert) |

## Architecture

### Image Delivery

The module creates Artifact Registry remote repositories that proxy upstream registries:

- **Community Edition**: Proxies `ghcr.io/imgproxy/imgproxy`
- **Pro Edition**: Proxies `docker.imgproxy.pro/imgproxy` with authentication

Cloud Run pulls images from these proxies, which cache layers in your project for faster cold starts.

### Monitoring

When `enable_monitoring = true`:

1. imgproxy is configured to send OTLP data to `http://localhost:4318` (HTTP) and `localhost:4317` (gRPC)
2. OpenTelemetry collector sidecar receives traces, metrics, and logs
3. Data is exported to Google Cloud Trace, Cloud Monitoring, and Cloud Logging
4. The service account is granted `roles/cloudtrace.agent`, `roles/monitoring.metricWriter`, and `roles/logging.logWriter`
5. The collector reads its config from `otel_collector_config`, which is mounted at `/etc/otel/config.yaml`

The following environment variables are automatically configured:
- `IMGPROXY_OPEN_TELEMETRY_ENABLE=true`
- `IMGPROXY_OPEN_TELEMETRY_ENABLE_METRICS=true`
- `IMGPROXY_OPEN_TELEMETRY_ENABLE_LOGS=true`
- `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318`
- `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf`
- `OTEL_SERVICE_NAME=<service_name>`

Access telemetry data in Cloud Console:
- Traces: Cloud Console → Trace → Trace List
- Metrics: Cloud Console → Monitoring → Metrics Explorer (search for `workload.googleapis.com`)
- Logs: Cloud Console → Logging → Logs Explorer (log name: `<service_name>`)

### GCS Integration

The module grants IAM permissions to existing buckets:

- **Source bucket**: sets `IMGPROXY_USE_GCS=true` enables `gs://` URL scheme
- **Cache bucket**: imgproxy Pro can cache processed results (configure via `environment` variable)

The module does not create buckets - you must create them before deployment.

## Security

### Private Deployment

Restrict access to VPC or load balancer only:

```hcl
module "imgproxy" {
  # ...

  ingress                 = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  allow_unauthenticated   = false
}
```

## Monitoring

### Health Check

The service exposes `/health` on port 8080:

```bash
curl https://your-service.run.app/health
# Output: imgproxy is running
```

### Logs

View logs in Cloud Console → Cloud Run → [service] → Logs, or via CLI:

```bash
gcloud logging read "resource.type=cloud_run_revision \
  resource.labels.service_name=imgproxy" \
  --limit=50 \
  --format=json
```

## Examples

See the [examples/](examples/) directory for additional use cases:

- [Complete](examples/complete/) - Full-featured deployment with Pro, monitoring, and GCS
- [Insecure](examples/insecure/) - Minimal insecure deployment for testing

## License

MIT

## Support

For imgproxy configuration questions, see the [official documentation](https://docs.imgproxy.net/).

For Terraform module issues, please open a GitHub issue.
