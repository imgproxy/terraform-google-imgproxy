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

Everything is configured in [main.tf](main.tf); edit it to enable the commented-out options (Bearer auth, source URL
encryption, trusted signatures, extra secrets, CDN).

1. **Deploy:**

```bash
terraform init
terraform apply -var project_id=my-gcp-project
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
gcloud storage cp test-image.jpg gs://my-gcp-project-imgproxy-source/
```

Then access it via imgproxy using a signed URL:

```bash
# Generate a signed URL using imgproxy's signing algorithm
# See: https://docs.imgproxy.net/usage/signing_the_url
curl "$(terraform output -raw url)/<signature>/plain/gs://my-gcp-project-imgproxy-source/test-image.jpg"
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
