# Signed URLs

Production imgproxy with request signing, so only URLs signed with your key and salt are processed.

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
