# GCS source bucket

imgproxy reading source images from a private GCS bucket via the `gs://` URL scheme. The module grants
`roles/storage.objectViewer` to the imgproxy service account, so the bucket stays private.

## Google Cloud setup

You need a Google Cloud project and the [gcloud CLI](https://cloud.google.com/sdk/docs/install), authenticated:

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

## Prerequisites

Create the signing keys and a private bucket for source images (see [signed](../signed/) for the keys):

```bash
PROJECT_ID=$(gcloud config get-value project)

openssl rand -hex 64 | gcloud secrets create imgproxy-keys --data-file=-
openssl rand -hex 64 | gcloud secrets create imgproxy-salts --data-file=-

gcloud storage buckets create gs://$PROJECT_ID-imgproxy-images \
  --location=us-central1 \
  --uniform-bucket-level-access
```

## Deploy

```bash
echo "project_id = \"$PROJECT_ID\"" > terraform.tfvars

terraform init
terraform plan
terraform apply

gcloud storage cp photo.jpg gs://$PROJECT_ID-imgproxy-images/photo.jpg
```

Sign the request as in [signed](../signed/), with `IMG_PATH` pointing at the bucket object:

```bash
(
URL=$(terraform output -raw url)
KEY=$(gcloud secrets versions access latest --secret=imgproxy-keys)
SALT=$(gcloud secrets versions access latest --secret=imgproxy-salts)
IMG_PATH="/rs:fit:300:200/plain/gs://$PROJECT_ID-imgproxy-images/photo.jpg"
SIG=$( (printf '%s' "$SALT" | xxd -r -p; printf '%s' "$IMG_PATH") \
  | openssl dgst -sha256 -mac HMAC -macopt hexkey:$KEY -binary \
  | openssl base64 -A | tr '+/' '-_' | tr -d '=' )
echo "$URL/$SIG$IMG_PATH"
)
```

The module does not create buckets: it only grants the imgproxy service account read access to the ones you list in `source_buckets`.

## Cleanup

```bash
terraform destroy
```

The bucket and the secrets were created with `gcloud`, so delete them separately:

```bash
gcloud storage rm -r gs://$PROJECT_ID-imgproxy-images
gcloud secrets delete imgproxy-keys
gcloud secrets delete imgproxy-salts
```

## Next

Continue with [cdn](../cdn/).
