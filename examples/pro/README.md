# imgproxy Pro

imgproxy Pro with a license key and a GCS result cache. It fetches public placeholder images, so no source bucket is needed.

## Google Cloud setup

You need a Google Cloud project and the [gcloud CLI](https://cloud.google.com/sdk/docs/install), authenticated:

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

## Prerequisites

Create the imgproxy Pro secrets, the signing keys (see [signed](../signed/)), and a private bucket for the result cache:

```bash
PROJECT_ID=$(gcloud config get-value project)

echo -n "your-license-key" | gcloud secrets create imgproxy-pro-license --data-file=-
echo -n "your-registry-password" | gcloud secrets create imgproxy-pro-password --data-file=-

openssl rand -hex 64 | gcloud secrets create imgproxy-keys --data-file=-
openssl rand -hex 64 | gcloud secrets create imgproxy-salts --data-file=-

gcloud storage buckets create gs://$PROJECT_ID-imgproxy-cache \
  --location=us-central1 \
  --uniform-bucket-level-access
```

## Deploy

```bash
echo "project_id = \"$PROJECT_ID\"" > terraform.tfvars

terraform init
terraform plan
terraform apply
```

Print a signed URL for a placeholder image (see [signed](../signed/) for how signing works) and open it:

```bash
(
URL=$(terraform output -raw url)
KEY=$(gcloud secrets versions access latest --secret=imgproxy-keys)
SALT=$(gcloud secrets versions access latest --secret=imgproxy-salts)
IMG_PATH="/rs:fit:300:200/plain/https://picsum.photos/1200/800.jpg"
SIG=$( (printf '%s' "$SALT" | xxd -r -p; printf '%s' "$IMG_PATH") \
  | openssl dgst -sha256 -mac HMAC -macopt hexkey:$KEY -binary \
  | openssl base64 -A | tr '+/' '-_' | tr -d '=' )
echo "$URL/$SIG$IMG_PATH"
)
```

imgproxy Pro caches processed results in the cache bucket (`cache_bucket`, Pro only), so repeated requests are
served faster. Request the URL printed above with `curl` and look for the `X-Imgproxy-Cache` response header:

```bash
curl -s -D- -o /dev/null "<url from above>" | grep -i x-imgproxy-cache
# A request for a new URL is processed and stored; repeating it returns "x-imgproxy-cache: Hit"
```

The processed results are stored in the cache bucket:

```bash
gcloud storage ls -r gs://$PROJECT_ID-imgproxy-cache
```

## Cleanup

```bash
terraform destroy
```

The bucket and the secrets were created with `gcloud`, so delete them separately:

```bash
gcloud storage rm -r gs://$PROJECT_ID-imgproxy-cache
gcloud secrets delete imgproxy-pro-license
gcloud secrets delete imgproxy-pro-password
gcloud secrets delete imgproxy-keys
gcloud secrets delete imgproxy-salts
```

## Next

Continue with [complete](../complete/).
