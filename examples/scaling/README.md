# Scaling

Signed imgproxy with every resource and scaling setting spelled out: instance size, concurrency per instance, the
instance count and CPU allocation.

## Google Cloud setup

You need a Google Cloud project and the [gcloud CLI](https://cloud.google.com/sdk/docs/install), authenticated:

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

## Prerequisites

Create the signing keys and store them in Secret Manager:

```bash
PROJECT_ID=$(gcloud config get-value project)

openssl rand -hex 64 | gcloud secrets create imgproxy-keys --data-file=-
openssl rand -hex 64 | gcloud secrets create imgproxy-salts --data-file=-
```

## Deploy

```bash
echo "project_id = \"$PROJECT_ID\"" > terraform.tfvars

terraform init
terraform plan
terraform apply

# Unsigned requests are rejected
curl -I "$(terraform output -raw url)/insecure/plain/https://picsum.photos/200"   # 403 Forbidden
```

Print a signed URL (paste it into a browser):

```bash
(
URL=$(terraform output -raw url)
KEY=$(gcloud secrets versions access latest --secret=imgproxy-keys)
SALT=$(gcloud secrets versions access latest --secret=imgproxy-salts)
IMG_PATH="/rs:fit:300:300/plain/https://picsum.photos/1200/800.jpg"
SIG=$( (printf '%s' "$SALT" | xxd -r -p; printf '%s' "$IMG_PATH") \
  | openssl dgst -sha256 -mac HMAC -macopt hexkey:$KEY -binary \
  | openssl base64 -A | tr '+/' '-_' | tr -d '=' )
echo "$URL/$SIG$IMG_PATH"
)
```

This assumes a single key/salt pair. See [imgproxy's signing algorithm](https://docs.imgproxy.net/usage/signing_the_url) for details.

## Scaling variables

- **Instance size**: `cpu` and `memory`.
- **Concurrency**: `workers` sets IMGPROXY_WORKERS and Cloud Run's `max_instance_request_concurrency`, the number of
  simultaneous requests one instance takes before Cloud Run starts another. It defaults to `cpu` x 2.
- **Instance count**: `min_instances` and `max_instances` bound the instances. A minimum of 1 avoids cold starts; 0
  scales to zero. `service_scaling` sets a service-level minimum independent of revisions and is left commented.
- **CPU and sandbox**: `cpu_idle = true` throttles the CPU between requests, `false` keeps it allocated (and billed).
  `execution_environment` selects the Gen1 or Gen2 sandbox.
- **Session affinity**: `session_affinity` is left commented; imgproxy is stateless.

## Cleanup

```bash
terraform destroy
```

The secrets created in Prerequisites are not managed by Terraform; delete them separately:

```bash
gcloud secrets delete imgproxy-keys
gcloud secrets delete imgproxy-salts
```

## Next

Continue with [gcs](../gcs/).
