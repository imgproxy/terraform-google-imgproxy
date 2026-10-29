# Insecure imgproxy Deployment Example

> [!WARNING]
> This example deploys imgproxy in **insecure mode** with no request signing. It is intended for **development and testing only**. Never use this configuration in production.

## Google Cloud setup

You need a Google Cloud project and the [gcloud CLI](https://cloud.google.com/sdk/docs/install), authenticated:

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

## What This Deploys

A minimal imgproxy deployment with:

- **No request signing** (`insecure = true`)
- Community edition (not Pro)
- Default resource limits (1 CPU, 512Mi memory)
- Public access allowed
- No monitoring sidecar
- No GCS integration

## Usage

1. **Deploy:**

```bash
echo 'project_id = "my-dev-project"' > terraform.tfvars

terraform init
terraform plan
terraform apply
```

2. **Test the service:**

```bash
# Get the URL
URL=$(terraform output -raw url)

# Process a remote image (no signature required in insecure mode)
curl "$URL/insecure/rs:fit:300:300/plain/https://example.com/image.jpg" -o output.jpg
```

## Why Insecure Mode is Dangerous

Without request signing:

- **Anyone can use your imgproxy** → unlimited bandwidth costs
- **No protection against abuse** → DDoS vulnerability
- **No control over processed images** → potential legal issues

## Cleanup

```bash
terraform destroy
```

## Next

Continue with [signed](../signed/).
