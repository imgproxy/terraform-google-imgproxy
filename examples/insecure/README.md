# Insecure mode

Minimal imgproxy on Cloud Run with no request signing (`insecure = true`): community edition, default resource
limits, public access, no monitoring and no GCS. It fetches public placeholder images.

> [!WARNING]
> This example is intended for **development and testing only**. Without request signing anyone can use your
> imgproxy (unlimited bandwidth costs, no protection against abuse, no control over processed images). Never use
> this configuration in production.

## Google Cloud setup

You need a Google Cloud project and the [gcloud CLI](https://cloud.google.com/sdk/docs/install), authenticated:

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

## Prerequisites

```bash
PROJECT_ID=$(gcloud config get-value project)
```

## Deploy

```bash
echo "project_id = \"$PROJECT_ID\"" > terraform.tfvars

terraform init
terraform plan
terraform apply
```

Print a ready-to-open URL (paste it into a browser; no signature is required in insecure mode):

```bash
echo "$(terraform output -raw url)/insecure/rs:fit:300:300/plain/https://picsum.photos/1200/800.jpg"
```

## Cleanup

```bash
terraform destroy
```

## Next

Continue with [signed](../signed/).
