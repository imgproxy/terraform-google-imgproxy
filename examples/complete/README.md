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

**Create Secret Manager secrets and GCS buckets:**

```bash
PROJECT_ID=$(gcloud config get-value project)

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

# GCS buckets for source images and the result cache (not managed by Terraform)
gcloud storage buckets create gs://$PROJECT_ID-imgproxy-complete-source \
  --location=us-central1 --uniform-bucket-level-access
gcloud storage buckets create gs://$PROJECT_ID-imgproxy-complete-cache \
  --location=us-central1 --uniform-bucket-level-access
```

## Deploy

Everything is configured in [main.tf](main.tf); edit it to enable the commented-out options (Bearer auth, source URL
encryption, trusted signatures, extra secrets, CDN).

1. **Deploy:**

```bash
echo "project_id = \"$PROJECT_ID\"" > terraform.tfvars

terraform init
terraform plan
terraform apply
```

2. **Access the service:**

```bash
terraform output url
```

3. **If CDN is enabled, point DNS:**

```bash
# Get the CDN static IP
terraform output cdn_ip_address

# Create an A record pointing cdn.example.com to this IP
# Google will provision a managed SSL certificate automatically (10–60 min)
```

## Testing GCS Integration

Upload a test image to the source bucket:

```bash
gcloud storage cp test-image.jpg gs://$PROJECT_ID-imgproxy-complete-source/photo.jpg
```

Then access it via imgproxy using a signed URL:

```bash
(
URL=$(terraform output -raw url)
KEY=$(gcloud secrets versions access latest --secret=imgproxy-keys)
SALT=$(gcloud secrets versions access latest --secret=imgproxy-salts)
IMG_PATH="/plain/gs://$PROJECT_ID-imgproxy-complete-source/photo.jpg"
SIG=$( (printf '%s' "$SALT" | xxd -r -p; printf '%s' "$IMG_PATH") \
  | openssl dgst -sha256 -mac HMAC -macopt hexkey:$KEY -binary \
  | openssl base64 -A | tr '+/' '-_' | tr -d '=' )
echo "$URL/$SIG$IMG_PATH"
)
```

## Verifying Monitoring

After deployment with `enable_monitoring = true`, verify telemetry is flowing:

1. Go to Cloud Console → Trace → Trace explorer and confirm new traces appear for imgproxy requests
2. Go to Cloud Console → Monitoring → Metrics Explorer, click **Select a metric**, untick **Active** if nothing is listed, and pick resource type **Generic Task** (`job` = `imgproxy`). The metrics are under the `workload.googleapis.com` prefix, e.g. `requests_total`, `request_duration_seconds`, `status_codes_total`, `workers_utilization`. They appear within a minute or two of the first requests
3. Go to Cloud Console → Logging → Logs Explorer and filter by your Cloud Run service name

## Cleanup

```bash
terraform destroy
```

The buckets and the secrets were created with `gcloud`, so delete them separately (and remove the DNS A record if you added a domain):

```bash
gcloud storage rm -r gs://$PROJECT_ID-imgproxy-complete-source gs://$PROJECT_ID-imgproxy-complete-cache
gcloud secrets delete imgproxy-keys
gcloud secrets delete imgproxy-salts
gcloud secrets delete imgproxy-pro-license
gcloud secrets delete imgproxy-pro-password
gcloud secrets delete imgproxy-secret
gcloud secrets delete imgproxy-source-url-key
```
