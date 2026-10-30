# Cloud CDN

Global HTTPS load balancer with Cloud CDN caching processed images at edge locations. A domain
name for the SSL certificate is recommended; this example runs without one, over plain HTTP on the load
balancer's static IP (see below for adding a domain). It fetches public placeholder images, so no bucket is needed.

## Google Cloud setup

You need a Google Cloud project and the [gcloud CLI](https://cloud.google.com/sdk/docs/install), authenticated:

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

## Prerequisites

Create the signing keys (see [signed](../signed/)):

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
```

The load balancer takes a few minutes to start serving. Print a signed URL for a placeholder image and request it twice:

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

# Repeated requests for the same URL: the second response carries an Age header (cache hit)
curl -sI "<url from above>" | grep -i -E '^(HTTP|age)'
```

Traffic, including signed URLs, is unencrypted in this mode. Use it for testing only.

## Adding a domain

In [main.tf](main.tf), uncomment `cdn_domains`, set your domain and switch `cdn_redirect_http_to_https` to `true`.
After `terraform apply`, point a DNS A record at `terraform output cdn_ip`. Google then provisions the managed
certificate, which takes 10-60 minutes.

## Redirect modes

- `cdn_redirect_http_to_https = true` (default): HTTP redirects to HTTPS. Recommended.
- `false`: HTTP goes straight to the backend. Only for testing without a valid domain/certificate.
  Required when neither `cdn_domains` nor `cdn_ssl_certificates` is set.

## SSL certificate options

- Managed (recommended, free, auto-renewed; needs the A record): `cdn_domains = ["cdn.example.com"]`
- Existing: `cdn_ssl_certificates = ["projects/my-project/global/sslCertificates/my-cert"]`
- None (testing only): omit both and set `cdn_redirect_http_to_https = false`. Only the HTTP listener is created,
  and the `url` output is `http://<static-ip>`. Traffic, including signed URLs, is unencrypted.

With CDN enabled, direct access to the Cloud Run URL is blocked
(`INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`); all traffic goes through the CDN.

## Cleanup

```bash
terraform destroy
```

The secrets were created with `gcloud`, so delete them separately (and remove the DNS A record if you added a domain):

```bash
gcloud secrets delete imgproxy-keys
gcloud secrets delete imgproxy-salts
```

## Next

Continue with [pro](../pro/).
