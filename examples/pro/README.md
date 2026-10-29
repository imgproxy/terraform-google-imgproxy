# imgproxy Pro

imgproxy Pro with a license key, GCS source bucket and GCS result cache.

## Google Cloud setup

You need a Google Cloud project and the [gcloud CLI](https://cloud.google.com/sdk/docs/install), authenticated:

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

## Prerequisites

```bash
echo -n "your-license-key" | gcloud secrets create imgproxy-pro-license --data-file=-
echo -n "your-registry-password" | gcloud secrets create imgproxy-pro-password --data-file=-

# Signing keys, see ../signed/
openssl rand -hex 64 | gcloud secrets create imgproxy-keys --data-file=-
openssl rand -hex 64 | gcloud secrets create imgproxy-salts --data-file=-
```

## Deploy

```bash
terraform init
terraform apply -var project_id=my-project
```

When `cache_bucket` is set (Pro only), imgproxy caches processed results in GCS for faster subsequent requests.
