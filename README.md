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
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | ~> 6.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_imgproxy_common"></a> [imgproxy\_common](#module\_imgproxy\_common) | github.com/imgproxy/terraform-common//imgproxy-common | 486e02b07505f547e546f219bb46dbaf1b7ebbf4 |

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

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID. | `string` | n/a | yes |
| <a name="input_allow_unauthenticated"></a> [allow\_unauthenticated](#input\_allow\_unauthenticated) | Whether to allow unauthenticated (public) requests. | `bool` | `true` | no |
| <a name="input_binary_authorization"></a> [binary\_authorization](#input\_binary\_authorization) | Binary Authorization settings. use\_default enables the project's default policy. | <pre>object({<br/>    breakglass_justification = optional(string)<br/>    use_default              = optional(bool)<br/>  })</pre> | `null` | no |
| <a name="input_cache_bucket"></a> [cache\_bucket](#input\_cache\_bucket) | Existing GCS bucket name for imgproxy result cache (imgproxy Pro only). The Cloud Run SA will be granted roles/storage.objectAdmin. Configure cache env vars via var.environment (https://docs.imgproxy.net/configuration/options#IMGPROXY_CACHE_BUCKET). | `string` | `null` | no |
| <a name="input_cdn_cache_mode"></a> [cdn\_cache\_mode](#input\_cdn\_cache\_mode) | CDN cache mode. Options: CACHE\_ALL\_STATIC, USE\_ORIGIN\_HEADERS, FORCE\_CACHE\_ALL. | `string` | `"CACHE_ALL_STATIC"` | no |
| <a name="input_cdn_client_ttl"></a> [cdn\_client\_ttl](#input\_cdn\_client\_ttl) | Client (browser) TTL in seconds. Overrides origin Cache-Control for client caching. | `number` | `3600` | no |
| <a name="input_cdn_default_ttl"></a> [cdn\_default\_ttl](#input\_cdn\_default\_ttl) | Default TTL in seconds for cached content when origin doesn't specify Cache-Control. | `number` | `2628000` | no |
| <a name="input_cdn_domains"></a> [cdn\_domains](#input\_cdn\_domains) | Domain names for managed SSL certificates (e.g., ['cdn.example.com']). Creates Google-managed certs with auto-renewal. Mutually exclusive with cdn\_ssl\_certificates. | `list(string)` | `[]` | no |
| <a name="input_cdn_log_sample_rate"></a> [cdn\_log\_sample\_rate](#input\_cdn\_log\_sample\_rate) | Fraction of CDN requests to write to Cloud Logging (0.0–1.0). 0.1 = 10%. Higher values increase observability but raise Cloud Logging ingestion costs significantly at scale. | `number` | `0.1` | no |
| <a name="input_cdn_max_ttl"></a> [cdn\_max\_ttl](#input\_cdn\_max\_ttl) | Maximum TTL in seconds that CDN will cache content, regardless of origin headers. | `number` | `31556926` | no |
| <a name="input_cdn_negative_caching"></a> [cdn\_negative\_caching](#input\_cdn\_negative\_caching) | Enable caching of error responses (4xx, 5xx). Reduces backend load for missing images. | `bool` | `true` | no |
| <a name="input_cdn_redirect_http_to_https"></a> [cdn\_redirect\_http\_to\_https](#input\_cdn\_redirect\_http\_to\_https) | Automatically redirect HTTP traffic to HTTPS. Recommended for security. Must be false when no certificate is configured (HTTP-only CDN, for testing). | `bool` | `true` | no |
| <a name="input_cdn_serve_while_stale"></a> [cdn\_serve\_while\_stale](#input\_cdn\_serve\_while\_stale) | Seconds Cloud CDN will serve stale content while revalidating in the background. 86400 = 24 hours. Prevents thundering-herd latency spikes when many cache entries expire simultaneously. Set to 0 to disable. | `number` | `86400` | no |
| <a name="input_cdn_ssl_certificates"></a> [cdn\_ssl\_certificates](#input\_cdn\_ssl\_certificates) | Names of existing SSL certificate resources. For externally managed certificates. Mutually exclusive with cdn\_domains. | `list(string)` | `[]` | no |
| <a name="input_cpu"></a> [cpu](#input\_cpu) | CPU limit for the container (e.g. 1, 2). | `number` | `1` | no |
| <a name="input_cpu_idle"></a> [cpu\_idle](#input\_cpu\_idle) | Throttle the CPU when no requests are being processed. Set to false to keep CPU always allocated. | `bool` | `true` | no |
| <a name="input_custom_audiences"></a> [custom\_audiences](#input\_custom\_audiences) | Custom audiences for this service, as full URLs. See https://cloud.google.com/run/docs/configuring/custom-audiences. | `list(string)` | `null` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Enable Terraform deletion protection on the Cloud Run service. When true, `terraform destroy` requires first setting this to false and applying. | `bool` | `false` | no |
| <a name="input_description"></a> [description](#input\_description) | Cloud Run service description. This field currently has a 512-character limit. | `string` | `null` | no |
| <a name="input_enable_cdn"></a> [enable\_cdn](#input\_enable\_cdn) | Enable Cloud CDN with global HTTPS load balancer. Creates static IP, backend, URL map, and SSL termination. | `bool` | `false` | no |
| <a name="input_enable_monitoring"></a> [enable\_monitoring](#input\_enable\_monitoring) | Enable the OpenTelemetry collector sidecar to send traces, metrics, and logs to Google Cloud Trace, Cloud Monitoring, and Cloud Logging. Automatically configures imgproxy OTEL environment variables. | `bool` | `false` | no |
| <a name="input_encryption_key"></a> [encryption\_key](#input\_encryption\_key) | Customer-managed encryption key (CMEK) reference to encrypt the container image. | `string` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Additional environment variables passed to imgproxy (e.g. IMGPROXY\_MAX\_SRC\_RESOLUTION). | `map(string)` | `{}` | no |
| <a name="input_execution_environment"></a> [execution\_environment](#input\_execution\_environment) | Sandbox environment for the revision. | `string` | `"EXECUTION_ENVIRONMENT_GEN2"` | no |
| <a name="input_ingress"></a> [ingress](#input\_ingress) | Cloud Run ingress setting. Use INGRESS\_TRAFFIC\_INTERNAL\_ONLY to restrict to VPC. | `string` | `"INGRESS_TRAFFIC_ALL"` | no |
| <a name="input_insecure"></a> [insecure](#input\_insecure) | Disable URL signature checks. When true, key and salt are not required and no secrets are created. | `bool` | `false` | no |
| <a name="input_keys_secret"></a> [keys\_secret](#input\_keys\_secret) | Secret Manager secret containing imgproxy signing keys (comma-separated hex-encoded values). Required when insecure = false. Generate each key: openssl rand -hex 64. Sets IMGPROXY\_KEY (https://docs.imgproxy.net/configuration/options#IMGPROXY_KEY). | <pre>object({<br/>    id      = string<br/>    version = optional(string, "latest")<br/>  })</pre> | `null` | no |
| <a name="input_launch_stage"></a> [launch\_stage](#input\_launch\_stage) | Cloud Run launch stage. Use BETA to enable beta features. Allowed: ALPHA, BETA, GA. | `string` | `"GA"` | no |
| <a name="input_location"></a> [location](#input\_location) | GCP location for all resources. | `string` | `"us-central1"` | no |
| <a name="input_max_instances"></a> [max\_instances](#input\_max\_instances) | Maximum number of Cloud Run instances. | `number` | `10` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Memory limit for the container (e.g. "512Mi", "2Gi"). | `string` | `"1024Mi"` | no |
| <a name="input_min_instances"></a> [min\_instances](#input\_min\_instances) | Minimum number of Cloud Run instances (set to 1 to avoid cold starts). | `number` | `1` | no |
| <a name="input_otel_collector_config"></a> [otel\_collector\_config](#input\_otel\_collector\_config) | OpenTelemetry collector configuration file mounted at /etc/otel/config.yaml when monitoring is enabled. Supports collector environment variable expansion such as ${GOOGLE\_CLOUD\_PROJECT}. | `string` | `"receivers:\n  otlp:\n    protocols:\n      http:\n        endpoint: 0.0.0.0:4318\n      grpc:\n        endpoint: 0.0.0.0:4317\n\nprocessors:\n  batch:\n\nexporters:\n  googlecloud:\n    project: ${GOOGLE_CLOUD_PROJECT}\n    metric:\n      prefix: workload.googleapis.com\n    log:\n      default_log_name: imgproxy\n\nservice:\n  pipelines:\n    traces:\n      receivers: [otlp]\n      processors: [batch]\n      exporters: [googlecloud]\n    metrics:\n      receivers: [otlp]\n      processors: [batch]\n      exporters: [googlecloud]\n    logs:\n      receivers: [otlp]\n      processors: [batch]\n      exporters: [googlecloud]\n"` | no |
| <a name="input_pro"></a> [pro](#input\_pro) | Use imgproxy Pro (docker.imgproxy.pro) instead of the community image (ghcr.io). | `bool` | `false` | no |
| <a name="input_pro_license_key_secret"></a> [pro\_license\_key\_secret](#input\_pro\_license\_key\_secret) | Secret Manager secret for the imgproxy Pro license key. Sets IMGPROXY\_LICENSE\_KEY (https://docs.imgproxy.net/configuration/options#IMGPROXY_LICENSE_KEY). | <pre>object({<br/>    id      = string<br/>    version = optional(string, "latest")<br/>  })</pre> | `null` | no |
| <a name="input_pro_registry_password_secret"></a> [pro\_registry\_password\_secret](#input\_pro\_registry\_password\_secret) | Secret Manager secret for the docker.imgproxy.pro registry password. Required when pro = true. Granted to the Artifact Registry Service Agent. | <pre>object({<br/>    id      = string<br/>    version = optional(string, "latest")<br/>  })</pre> | `null` | no |
| <a name="input_repo"></a> [repo](#input\_repo) | Custom container repository to use. When set, overrides the repository constructed from 'pro'. Combined with 'tag' to form the full image reference (e.g. 'gcr.io/my-project/imgproxy'). | `string` | `null` | no |
| <a name="input_revision"></a> [revision](#input\_revision) | Pinned revision name. When omitted, Cloud Run generates a name automatically. | `string` | `null` | no |
| <a name="input_salts_secret"></a> [salts\_secret](#input\_salts\_secret) | Secret Manager secret containing imgproxy signing salts (comma-separated hex-encoded values). Must match the number of keys. Required when insecure = false. Sets IMGPROXY\_SALT (https://docs.imgproxy.net/configuration/options#IMGPROXY_SALT). | <pre>object({<br/>    id      = string<br/>    version = optional(string, "latest")<br/>  })</pre> | `null` | no |
| <a name="input_secret_secret"></a> [secret\_secret](#input\_secret\_secret) | Secret Manager secret for the authorization token. When set, requests must include Authorization: Bearer <token>. Sets IMGPROXY\_SECRET (https://docs.imgproxy.net/configuration/options#IMGPROXY_SECRET). | <pre>object({<br/>    id      = string<br/>    version = optional(string, "latest")<br/>  })</pre> | `null` | no |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Map of environment variable names to Secret Manager secrets. Example: {IMGPROXY\_NEW\_RELIC\_KEY = { id = "projects/PROJECT/secrets/newrelic-key" }, IMGPROXY\_SENTRY\_DSN = { id = "projects/PROJECT/secrets/sentry-dsn", version = "3" }}. | <pre>map(object({<br/>    id      = string<br/>    version = optional(string, "latest")<br/>  }))</pre> | `{}` | no |
| <a name="input_service_account"></a> [service\_account](#input\_service\_account) | Email of an existing service account to attach to the Cloud Run service. When null, a dedicated service account is created automatically. | `string` | `null` | no |
| <a name="input_service_annotations"></a> [service\_annotations](#input\_service\_annotations) | Annotations applied to the Cloud Run service. | `map(string)` | `{}` | no |
| <a name="input_service_labels"></a> [service\_labels](#input\_service\_labels) | Labels applied to the Cloud Run service. | `map(string)` | `{}` | no |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | Prefix applied to every resource name. | `string` | `"imgproxy"` | no |
| <a name="input_service_scaling"></a> [service\_scaling](#input\_service\_scaling) | Service-level minimum instance count (independent of revision scaling). | <pre>object({<br/>    min_instance_count = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_session_affinity"></a> [session\_affinity](#input\_session\_affinity) | Enables session affinity. See https://cloud.google.com/run/docs/configuring/session-affinity. | `string` | `null` | no |
| <a name="input_signature_size"></a> [signature\_size](#input\_signature\_size) | Number of bytes from the key/salt used for signing. Sets IMGPROXY\_SIGNATURE\_SIZE (https://docs.imgproxy.net/configuration/options#IMGPROXY_SIGNATURE_SIZE). | `number` | `32` | no |
| <a name="input_source_buckets"></a> [source\_buckets](#input\_source\_buckets) | GCS bucket names for imgproxy source images. The Cloud Run SA will be granted roles/storage.objectViewer on each. When non-empty, enables IMGPROXY\_USE\_GCS (https://docs.imgproxy.net/configuration/options#IMGPROXY_USE_GCS). | `list(string)` | `[]` | no |
| <a name="input_source_url_encryption_key_secret"></a> [source\_url\_encryption\_key\_secret](#input\_source\_url\_encryption\_key\_secret) | Secret Manager secret for the source URL encryption key. Sets IMGPROXY\_SOURCE\_URL\_ENCRYPTION\_KEY (https://docs.imgproxy.net/configuration/options#IMGPROXY_SOURCE_URL_ENCRYPTION_KEY). | <pre>object({<br/>    id      = string<br/>    version = optional(string, "latest")<br/>  })</pre> | `null` | no |
| <a name="input_tag"></a> [tag](#input\_tag) | imgproxy image tag (version). | `string` | `"v4"` | no |
| <a name="input_template_annotations"></a> [template\_annotations](#input\_template\_annotations) | Annotations applied to the Cloud Run revision template. | `map(string)` | `{}` | no |
| <a name="input_template_labels"></a> [template\_labels](#input\_template\_labels) | Labels applied to the Cloud Run revision template. | `map(string)` | `{}` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Request timeout in seconds. Sets IMGPROXY\_TIMEOUT (https://docs.imgproxy.net/configuration/options#IMGPROXY_TIMEOUT) and CDN backend timeout\_sec. Defaults to Cloud Run's default (300s) and CDN default (30s) when null. | `number` | `null` | no |
| <a name="input_traffic"></a> [traffic](#input\_traffic) | Traffic distribution across revisions. Defaults to 100% to the latest ready revision. | <pre>list(object({<br/>    type     = optional(string, "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST")<br/>    percent  = optional(number, 100)<br/>    revision = optional(string, null)<br/>    tag      = optional(string, null)<br/>  }))</pre> | `[]` | no |
| <a name="input_trusted_signatures_secret"></a> [trusted\_signatures\_secret](#input\_trusted\_signatures\_secret) | Secret Manager secret for trusted signature prefixes. imgproxy Pro only. Sets IMGPROXY\_TRUSTED\_SIGNATURES (https://docs.imgproxy.net/configuration/options#IMGPROXY_TRUSTED_SIGNATURES). | <pre>object({<br/>    id      = string<br/>    version = optional(string, "latest")<br/>  })</pre> | `null` | no |
| <a name="input_vpc_access"></a> [vpc\_access](#input\_vpc\_access) | Configure VPC access. Set egress to ALL\_TRAFFIC or PRIVATE\_RANGES\_ONLY. Choose a connector or network\_interfaces for direct VPC egress. | <pre>object({<br/>    connector = optional(string)<br/>    egress    = optional(string)<br/>    network_interfaces = optional(object({<br/>      network    = optional(string)<br/>      subnetwork = optional(string)<br/>      tags       = optional(list(string))<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_workers"></a> [workers](#input\_workers) | Number of concurrent requests per instance. Sets both IMGPROXY\_WORKERS (https://docs.imgproxy.net/configuration/options#IMGPROXY_WORKERS) and max\_instance\_request\_concurrency (Cloud Run). Defaults to cpu × 2. | `number` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cdn_ip_address"></a> [cdn\_ip\_address](#output\_cdn\_ip\_address) | Static IP address of the CDN load balancer. Point your DNS A record to this IP. |
| <a name="output_cdn_managed_certificate_id"></a> [cdn\_managed\_certificate\_id](#output\_cdn\_managed\_certificate\_id) | ID of the managed SSL certificate. Check status in Cloud Console under Load Balancing > Certificates. |
| <a name="output_location"></a> [location](#output\_location) | The region where the Cloud Run service is deployed. Use this to create a Serverless NEG when attaching a load balancer. |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | Email of the imgproxy service account. |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | The Cloud Run service name. |
| <a name="output_url"></a> [url](#output\_url) | The imgproxy endpoint URL. When enable\_cdn = true and cdn\_domains is set, returns the first domain as HTTPS. When only cdn\_ssl\_certificates is provided, returns the static IP as HTTPS. With enable\_cdn = true and no certificate, returns the static IP as HTTP. Otherwise returns the Cloud Run service URL. |
<!-- END_TF_DOCS -->

## License

MIT
