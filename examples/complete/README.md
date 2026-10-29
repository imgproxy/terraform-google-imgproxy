# Complete imgproxy Deployment Example

This example demonstrates a full-featured imgproxy deployment with all available features:

- imgproxy Pro with license key
- Request signing with configurable key size
- Source URL encryption
- Authorization token (Bearer auth)
- OpenTelemetry-based monitoring
- GCS integration for source images and result cache
- Cloud CDN with global HTTPS load balancer
- Additional secrets for third-party integrations
- Custom resource limits, concurrency, and scaling
- Service and template labels

## Google Cloud setup

You need a Google Cloud project and the [gcloud CLI](https://cloud.google.com/sdk/docs/install), authenticated:

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

## Prerequisites

**Create Secret Manager secrets:**

```bash
# Signing keys (required)
openssl rand -hex 64 | gcloud secrets create imgproxy-keys --data-file=-
openssl rand -hex 64 | gcloud secrets create imgproxy-salts --data-file=-

# imgproxy Pro (if using pro = true)
echo -n "your-license-key" | gcloud secrets create imgproxy-pro-license --data-file=-
echo -n "your-registry-password" | gcloud secrets create imgproxy-pro-password --data-file=-

# Optional: authorization token (Bearer auth)
openssl rand -hex 32 | gcloud secrets create imgproxy-secret --data-file=-

# Optional: source URL encryption key
openssl rand -hex 16 | gcloud secrets create imgproxy-source-url-key --data-file=-
```

## Usage

1. **Create a `terraform.tfvars` file:**

```hcl
project_id   = "my-gcp-project"
location     = "us-central1"
service_name = "imgproxy"
description  = "imgproxy image processing service"

# Security
keys_secret_id  = "imgproxy-keys"
salts_secret_id = "imgproxy-salts"
signature_size  = 32

# Optional: Bearer token auth (cannot be used with enable_cdn = true)
# secret_secret_id = "projects/my-gcp-project/secrets/imgproxy-secret"

# Optional: source URL encryption
# source_url_encryption_key_secret_id = "projects/my-gcp-project/secrets/imgproxy-source-url-key"

# imgproxy Pro (optional)
pro                             = true
pro_license_key_secret_id       = "imgproxy-pro-license"
pro_registry_password_secret_id = "projects/my-gcp-project/secrets/imgproxy-pro-password"

# Optional: trusted signatures (Pro only)
# trusted_signatures_secret_id = "projects/my-gcp-project/secrets/imgproxy-trusted-sigs"

# Additional secrets for third-party integrations (optional)
# secrets = {
#   IMGPROXY_NEW_RELIC_KEY = { secret = "projects/my-gcp-project/secrets/newrelic-license" }
#   IMGPROXY_SENTRY_DSN    = { secret = "projects/my-gcp-project/secrets/sentry-dsn", version = "3" }
# }

# GCS integration (optional)
source_buckets = ["my-project-imgproxy-source"]
cache_bucket  = "my-project-imgproxy-cache"

# Monitoring
enable_monitoring = true

# Compute resources
cpu     = "2"
memory  = "2Gi"
workers = 4
timeout = 60

# Scaling
min_instances = 2
max_instances = 20
service_scaling = {
  min_instance_count = 2
}

# Access control
ingress               = "INGRESS_TRAFFIC_ALL"
allow_unauthenticated = true

# Labels
service_labels = {
  app  = "imgproxy"
  team = "platform"
}

# Cloud CDN (optional — requires a domain name)
# enable_cdn                 = true
# cdn_domains                = ["cdn.example.com"]
# cdn_cache_mode             = "CACHE_ALL_STATIC"
# cdn_default_ttl            = 3600
# cdn_max_ttl                = 86400
# cdn_client_ttl             = 3600
# cdn_negative_caching       = true
# cdn_redirect_http_to_https = true
```

2. **Deploy:**

```bash
terraform init
terraform plan
terraform apply
```

3. **Access the service:**

```bash
terraform output url
```

4. **If CDN is enabled, point DNS:**

```bash
# Get the CDN static IP
terraform output cdn_ip_address

# Create an A record pointing cdn.example.com to this IP
# Google will provision a managed SSL certificate automatically (10–60 min)
```

## Testing GCS Integration

Upload a test image to the source bucket:

```bash
gcloud storage cp test-image.jpg gs://my-project-imgproxy-source/
```

Then access it via imgproxy using a signed URL:

```bash
# Generate a signed URL using imgproxy's signing algorithm
# See: https://docs.imgproxy.net/usage/signing_the_url
curl "$(terraform output -raw url)/<signature>/plain/gs://my-project-imgproxy-source/test-image.jpg"
```

## Verifying Monitoring

After deployment with `enable_monitoring = true`, verify telemetry is flowing:

1. Go to Cloud Console → Trace → Trace List and confirm new traces appear for imgproxy requests
2. Go to Cloud Console → Monitoring → Metrics Explorer and search for `workload.googleapis.com`
3. Go to Cloud Console → Logging → Logs Explorer and filter by your Cloud Run service name

## Cleanup

```bash
terraform destroy
```

Note: You'll need to manually delete the GCS buckets if they contain objects.
