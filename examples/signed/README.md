# Signed URLs

Production imgproxy with request signing, so only URLs signed with your key and salt are processed.

## Prerequisites

Create the signing keys and store them in Secret Manager:

```bash
openssl rand -hex 64 | gcloud secrets create imgproxy-keys --data-file=-
openssl rand -hex 64 | gcloud secrets create imgproxy-salts --data-file=-
```

## Deploy

```bash
terraform init
terraform apply -var project_id=my-project

URL=$(terraform output -raw url)

# Unsigned requests are rejected
curl -I "$URL/insecure/plain/https://picsum.photos/200"   # 403 Forbidden
```

Generate signed URLs with [imgproxy's signing algorithm](https://docs.imgproxy.net/usage/signing_the_url).
