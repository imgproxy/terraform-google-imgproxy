# imgproxy Terraform Module for Google Cloud Run

Terraform module to deploy [imgproxy](https://imgproxy.net/) on Google Cloud Run with optional Cloud CDN, OpenTelemetry-based monitoring, and GCS integration.

## Features

- **Cloud Run v2 deployment** with configurable CPU, memory, and scaling
- **Cloud CDN integration** with global HTTPS load balancer for caching and low-latency access worldwide
- **imgproxy Pro support** via Artifact Registry remote repository with authentication
- **OpenTelemetry collector sidecar** for traces, metrics, and logs to Cloud Trace, Cloud Monitoring, and Cloud Logging
- **GCS bucket integration** for source images and result cache (Pro)
- **Request signing** with keys and salts from Secret Manager
- **Artifact Registry remote repositories** for transparent image caching from ghcr.io and docker.imgproxy.pro
- **VPC access** support for private network egress

## Usage

Create the signing keys in Secret Manager first:

```bash
openssl rand -hex 64 | gcloud secrets create imgproxy-keys --data-file=-
openssl rand -hex 64 | gcloud secrets create imgproxy-salts --data-file=-
```

```hcl
module "imgproxy" {
  source  = "imgproxy/imgproxy/google"
  version = "~> 1.0"

  project_id   = "my-project"
  service_name = "imgproxy"

  keys_secret = {
    id = "projects/my-project/secrets/imgproxy-keys"
  }
  salts_secret = {
    id = "projects/my-project/secrets/imgproxy-salts"
  }
}

output "url" {
  value = module.imgproxy.url
}
```

Unsigned requests are rejected; sign URLs with [imgproxy's signing algorithm](https://docs.imgproxy.net/usage/signing_the_url).

## Examples

- [signed](examples/signed/) - Production setup with URL signing
- [gcs](examples/gcs/) - Private GCS bucket as the image source
- [pro](examples/pro/) - imgproxy Pro with license key and GCS result cache
- [custom-image](examples/custom-image/) - Custom image or your own Artifact Registry mirror
- [cdn](examples/cdn/) - Cloud CDN with a global HTTPS load balancer
- [complete](examples/complete/) - Full-featured deployment with Pro, monitoring, and GCS
- [insecure](examples/insecure/) - Minimal deployment without request signing (development only)

## Notes

### Additional secrets

The `secrets` variable maps extra environment variables to Secret Manager secrets, for integrations such as error tracking:

```hcl
secrets = {
  IMGPROXY_SENTRY_DSN = { id = "projects/my-project/secrets/sentry-dsn" }
  IMGPROXY_BUGSNAG_KEY = { id = "projects/my-project/secrets/bugsnag-api-key", version = "3" }
}
```

Names should match [imgproxy's configuration](https://docs.imgproxy.net/configuration).

### Image delivery

The module creates Artifact Registry remote repositories that proxy `ghcr.io/imgproxy/imgproxy` (Community) or `docker.imgproxy.pro/imgproxy` (Pro, authenticated). Cloud Run pulls from these proxies, which cache layers in your project. Setting `repo` skips them.

### Monitoring

With `enable_monitoring = true`, an OpenTelemetry collector sidecar receives OTLP data from imgproxy on `localhost:4318` (HTTP) and `localhost:4317` (gRPC) and exports it to Cloud Trace, Cloud Monitoring, and Cloud Logging. The service account is granted `roles/cloudtrace.agent`, `roles/monitoring.metricWriter`, and `roles/logging.logWriter`. The collector config comes from `otel_collector_config`, mounted at `/etc/otel/config.yaml`.

### GCS integration

The module grants IAM permissions on existing buckets and does not create them. `source_buckets` enables the `gs://` URL scheme; `cache_bucket` (Pro) is for processed results, configured via `environment`.

### Private deployment

```hcl
ingress               = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
allow_unauthenticated = false
```

With `enable_cdn = true`, direct access to the Cloud Run URL is blocked automatically.

### Health check and logs

The service exposes `/health` on port 8080. Logs are in Cloud Console → Cloud Run → service → Logs.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

## License

MIT
