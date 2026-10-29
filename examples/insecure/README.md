# Insecure imgproxy Deployment Example

> [!WARNING]
> This example deploys imgproxy in **insecure mode** with no request signing. It is intended for **development and testing only**. Never use this configuration in production.

## What This Deploys

A minimal imgproxy deployment with:

- **No request signing** (`insecure = true`)
- Community edition (not Pro)
- Default resource limits (1 CPU, 512Mi memory)
- Public access allowed
- No monitoring sidecar
- No GCS integration

## Usage

1. **Create a `terraform.tfvars` file:**

```hcl
project_id = "my-dev-project"
```

2. **Deploy:**

```bash
terraform init
terraform plan
terraform apply
```

3. **Test the service:**

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

## Migrating to Production

To make this deployment production-ready:

1. **Enable request signing:**

```bash
# Generate keys
openssl rand -hex 64 | gcloud secrets create imgproxy-keys --data-file=-
openssl rand -hex 64 | gcloud secrets create imgproxy-salts --data-file=-
```

2. **Update your configuration:**

```hcl
module "imgproxy" {
  # ...

  insecure        = false
  keys_secret_id  = "imgproxy-keys"
  salts_secret_id = "imgproxy-salts"
}
```

3. **Sign your requests:**

See the [imgproxy documentation](https://docs.imgproxy.net/signing_the_url) for how to generate signed URLs.

## Cleanup

```bash
terraform destroy
```
