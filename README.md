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

- [insecure](examples/insecure/) - Minimal deployment without request signing (development only)
- [signed](examples/signed/) - Production setup with URL signing
- [gcs](examples/gcs/) - Private GCS bucket as the image source
- [cdn](examples/cdn/) - Cloud CDN with a global HTTPS load balancer
- [pro](examples/pro/) - imgproxy Pro with license key and GCS result cache
- [custom-image](examples/custom-image/) - Custom image or your own Artifact Registry mirror
- [complete](examples/complete/) - Full-featured deployment with Pro, monitoring, and GCS

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

### Vendored module

`modules/imgproxy-common` is a generated copy of the module of the same name in `imgproxy/terraform-common`. Do not edit it here: change it upstream and run `sync.sh` from that repository.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.5 |
| google | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| google | ~> 6.0 |
| terraform | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| imgproxy\_common | ./modules/imgproxy-common | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [google_artifact_registry_repository.ghcr](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository) | resource |
| [google_artifact_registry_repository.pro](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository) | resource |
| [google_cloud_run_v2_service.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service) | resource |
| [google_cloud_run_v2_service_iam_member.public](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam_member) | resource |
| [google_compute_backend_service.cdn](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service) | resource |
| [google_compute_global_address.cdn](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_global_forwarding_rule.cdn](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_global_forwarding_rule.cdn_http](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_managed_ssl_certificate.cdn](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_managed_ssl_certificate) | resource |
| [google_compute_region_network_endpoint_group.cdn](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_network_endpoint_group) | resource |
| [google_compute_target_http_proxy.cdn_http](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_http_proxy) | resource |
| [google_compute_target_http_proxy.cdn_redirect](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_http_proxy) | resource |
| [google_compute_target_https_proxy.cdn](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_https_proxy) | resource |
| [google_compute_url_map.cdn](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |
| [google_compute_url_map.cdn_http_redirect](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |
| [google_project_iam_member.otel_logs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.otel_metrics](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.otel_trace](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.apis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_secret_manager_secret.otel_collector_config](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_iam_member.artifact_registry](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_iam_member.cloud_run](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_iam_member.otel_config](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_version.otel_collector_config](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_service_account.imgproxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_storage_bucket_iam_member.cache](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_iam_member.source](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [terraform_data.monitoring_config](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.secret_config](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Required |
| ---- | ----------- | ---- | :------: |
| project\_id | GCP project ID. | `string` | yes |
| allow\_unauthenticated | Whether to allow unauthenticated (public) requests. | `bool` | no |
| binary\_authorization | Binary Authorization settings. use\_default enables the project's default policy. | ```object({ breakglass_justification = optional(string) use_default = optional(bool) })``` | no |
| cache\_bucket | Existing GCS bucket name for imgproxy result cache (imgproxy Pro only). The Cloud Run SA will be granted roles/storage.objectAdmin. Configure cache env vars via var.environment (https://docs.imgproxy.net/configuration/options#IMGPROXY_CACHE_BUCKET). | `string` | no |
| cdn\_cache\_mode | CDN cache mode. Options: CACHE\_ALL\_STATIC, USE\_ORIGIN\_HEADERS, FORCE\_CACHE\_ALL. | `string` | no |
| cdn\_client\_ttl | Client (browser) TTL in seconds. Overrides origin Cache-Control for client caching. | `number` | no |
| cdn\_default\_ttl | Default TTL in seconds for cached content when origin doesn't specify Cache-Control. | `number` | no |
| cdn\_domains | Domain names for managed SSL certificates (e.g., ['cdn.example.com']). Creates Google-managed certs with auto-renewal. Mutually exclusive with cdn\_ssl\_certificates. | `list(string)` | no |
| cdn\_log\_sample\_rate | Fraction of CDN requests to write to Cloud Logging (0.0–1.0). 0.1 = 10%. Higher values increase observability but raise Cloud Logging ingestion costs significantly at scale. | `number` | no |
| cdn\_max\_ttl | Maximum TTL in seconds that CDN will cache content, regardless of origin headers. | `number` | no |
| cdn\_negative\_caching | Enable caching of error responses (4xx, 5xx). Reduces backend load for missing images. | `bool` | no |
| cdn\_redirect\_http\_to\_https | Automatically redirect HTTP traffic to HTTPS. Recommended for security. Must be false when no certificate is configured (HTTP-only CDN, for testing). | `bool` | no |
| cdn\_serve\_while\_stale | Seconds Cloud CDN will serve stale content while revalidating in the background. 86400 = 24 hours. Prevents thundering-herd latency spikes when many cache entries expire simultaneously. Set to 0 to disable. | `number` | no |
| cdn\_ssl\_certificates | Names of existing SSL certificate resources. For externally managed certificates. Mutually exclusive with cdn\_domains. | `list(string)` | no |
| cpu | CPU limit for the container (e.g. 1, 2). | `number` | no |
| cpu\_idle | Throttle the CPU when no requests are being processed. Set to false to keep CPU always allocated. | `bool` | no |
| custom\_audiences | Custom audiences for this service, as full URLs. See https://cloud.google.com/run/docs/configuring/custom-audiences. | `list(string)` | no |
| deletion\_protection | Enable Terraform deletion protection on the Cloud Run service. When true, `terraform destroy` requires first setting this to false and applying. | `bool` | no |
| description | Cloud Run service description. This field currently has a 512-character limit. | `string` | no |
| enable\_cdn | Enable Cloud CDN with global HTTPS load balancer. Creates static IP, backend, URL map, and SSL termination. | `bool` | no |
| enable\_monitoring | Enable the OpenTelemetry collector sidecar to send traces, metrics, and logs to Google Cloud Trace, Cloud Monitoring, and Cloud Logging. Automatically configures imgproxy OTEL environment variables. | `bool` | no |
| encryption\_key | Customer-managed encryption key (CMEK) reference to encrypt the container image. | `string` | no |
| environment | Additional environment variables passed to imgproxy (e.g. IMGPROXY\_MAX\_SRC\_RESOLUTION). | `map(string)` | no |
| execution\_environment | Sandbox environment for the revision. | `string` | no |
| ingress | Cloud Run ingress setting. Use INGRESS\_TRAFFIC\_INTERNAL\_ONLY to restrict to VPC. | `string` | no |
| insecure | Disable URL signature checks. When true, key and salt are not required and no secrets are created. | `bool` | no |
| keys\_secret | Secret Manager secret containing imgproxy signing keys (comma-separated hex-encoded values). Required when insecure = false. Generate each key: openssl rand -hex 64. Sets IMGPROXY\_KEY (https://docs.imgproxy.net/configuration/options#IMGPROXY_KEY). | ```object({ id = string version = optional(string, "latest") })``` | no |
| launch\_stage | Cloud Run launch stage. Use BETA to enable beta features. Allowed: ALPHA, BETA, GA. | `string` | no |
| location | GCP location for all resources. | `string` | no |
| max\_instances | Maximum number of Cloud Run instances. | `number` | no |
| memory | Memory limit for the container (e.g. "512Mi", "2Gi"). | `string` | no |
| min\_instances | Minimum number of Cloud Run instances (set to 1 to avoid cold starts). | `number` | no |
| otel\_collector\_config | OpenTelemetry collector configuration file mounted at /etc/otel/config.yaml when monitoring is enabled. Supports collector environment variable expansion such as ${GOOGLE\_CLOUD\_PROJECT}. | `string` | no |
| pro | Use imgproxy Pro (docker.imgproxy.pro) instead of the community image (ghcr.io). | `bool` | no |
| pro\_license\_key\_secret | Secret Manager secret for the imgproxy Pro license key. Sets IMGPROXY\_LICENSE\_KEY (https://docs.imgproxy.net/configuration/options#IMGPROXY_LICENSE_KEY). | ```object({ id = string version = optional(string, "latest") })``` | no |
| pro\_registry\_password\_secret | Secret Manager secret for the docker.imgproxy.pro registry password. Required when pro = true. Granted to the Artifact Registry Service Agent. | ```object({ id = string version = optional(string, "latest") })``` | no |
| repo | Custom container repository to use. When set, overrides the repository constructed from 'pro'. Combined with 'tag' to form the full image reference (e.g. 'gcr.io/my-project/imgproxy'). | `string` | no |
| revision | Pinned revision name. When omitted, Cloud Run generates a name automatically. | `string` | no |
| salts\_secret | Secret Manager secret containing imgproxy signing salts (comma-separated hex-encoded values). Must match the number of keys. Required when insecure = false. Sets IMGPROXY\_SALT (https://docs.imgproxy.net/configuration/options#IMGPROXY_SALT). | ```object({ id = string version = optional(string, "latest") })``` | no |
| secret\_secret | Secret Manager secret for the authorization token. When set, requests must include Authorization: Bearer <token>. Sets IMGPROXY\_SECRET (https://docs.imgproxy.net/configuration/options#IMGPROXY_SECRET). | ```object({ id = string version = optional(string, "latest") })``` | no |
| secrets | Map of environment variable names to Secret Manager secrets. Example: {IMGPROXY\_NEW\_RELIC\_KEY = { id = "projects/PROJECT/secrets/newrelic-key" }, IMGPROXY\_SENTRY\_DSN = { id = "projects/PROJECT/secrets/sentry-dsn", version = "3" }}. | ```map(object({ id = string version = optional(string, "latest") }))``` | no |
| service\_account | Email of an existing service account to attach to the Cloud Run service. When null, a dedicated service account is created automatically. | `string` | no |
| service\_annotations | Annotations applied to the Cloud Run service. | `map(string)` | no |
| service\_labels | Labels applied to the Cloud Run service. | `map(string)` | no |
| service\_name | Prefix applied to every resource name. | `string` | no |
| service\_scaling | Service-level minimum instance count (independent of revision scaling). | ```object({ min_instance_count = optional(number) })``` | no |
| session\_affinity | Enables session affinity. See https://cloud.google.com/run/docs/configuring/session-affinity. | `string` | no |
| signature\_size | Number of bytes from the key/salt used for signing. Sets IMGPROXY\_SIGNATURE\_SIZE (https://docs.imgproxy.net/configuration/options#IMGPROXY_SIGNATURE_SIZE). | `number` | no |
| source\_buckets | GCS bucket names for imgproxy source images. The Cloud Run SA will be granted roles/storage.objectViewer on each. When non-empty, enables IMGPROXY\_USE\_GCS (https://docs.imgproxy.net/configuration/options#IMGPROXY_USE_GCS). | `list(string)` | no |
| source\_url\_encryption\_key\_secret | Secret Manager secret for the source URL encryption key. Sets IMGPROXY\_SOURCE\_URL\_ENCRYPTION\_KEY (https://docs.imgproxy.net/configuration/options#IMGPROXY_SOURCE_URL_ENCRYPTION_KEY). | ```object({ id = string version = optional(string, "latest") })``` | no |
| tag | imgproxy image tag (version). | `string` | no |
| template\_annotations | Annotations applied to the Cloud Run revision template. | `map(string)` | no |
| template\_labels | Labels applied to the Cloud Run revision template. | `map(string)` | no |
| timeout | Request timeout in seconds. Sets IMGPROXY\_TIMEOUT (https://docs.imgproxy.net/configuration/options#IMGPROXY_TIMEOUT) and CDN backend timeout\_sec. Defaults to Cloud Run's default (300s) and CDN default (30s) when null. | `number` | no |
| traffic | Traffic distribution across revisions. Defaults to 100% to the latest ready revision. | ```list(object({ type = optional(string, "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST") percent = optional(number, 100) revision = optional(string, null) tag = optional(string, null) }))``` | no |
| trusted\_signatures\_secret | Secret Manager secret for trusted signature prefixes. imgproxy Pro only. Sets IMGPROXY\_TRUSTED\_SIGNATURES (https://docs.imgproxy.net/configuration/options#IMGPROXY_TRUSTED_SIGNATURES). | ```object({ id = string version = optional(string, "latest") })``` | no |
| vpc\_access | Configure VPC access. Set egress to ALL\_TRAFFIC or PRIVATE\_RANGES\_ONLY. Choose a connector or network\_interfaces for direct VPC egress. | ```object({ connector = optional(string) egress = optional(string) network_interfaces = optional(object({ network = optional(string) subnetwork = optional(string) tags = optional(list(string)) })) })``` | no |
| workers | Number of concurrent requests per instance. Sets both IMGPROXY\_WORKERS (https://docs.imgproxy.net/configuration/options#IMGPROXY_WORKERS) and max\_instance\_request\_concurrency (Cloud Run). Defaults to cpu × 2. | `number` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| cdn\_ip\_address | Static IP address of the CDN load balancer. Point your DNS A record to this IP. |
| cdn\_managed\_certificate\_id | ID of the managed SSL certificate. Check status in Cloud Console under Load Balancing > Certificates. |
| location | The region where the Cloud Run service is deployed. Use this to create a Serverless NEG when attaching a load balancer. |
| service\_account\_email | Email of the imgproxy service account. |
| service\_name | The Cloud Run service name. |
| url | The imgproxy endpoint URL. When enable\_cdn = true and cdn\_domains is set, returns the first domain as HTTPS. When only cdn\_ssl\_certificates is provided, returns the static IP as HTTPS. With enable\_cdn = true and no certificate, returns the static IP as HTTP. Otherwise returns the Cloud Run service URL. |
<!-- END_TF_DOCS -->

## License

MIT
