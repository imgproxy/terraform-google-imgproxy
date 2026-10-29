# Cloud CDN

Global HTTPS load balancer with Cloud CDN caching processed images at edge locations. A domain
name for the SSL certificate is recommended (see below for testing without one). Signing keys are required; see [signed](../signed/).

```bash
terraform init
terraform apply -var project_id=my-project

terraform output cdn_ip
# Point a DNS A record at it, e.g. cdn.example.com.  A  8.232.52.166
```

Google then provisions the managed certificate, which takes 10-60 minutes. Once it is ACTIVE:

```bash
curl -I https://cdn.example.com/health
# Repeated requests for the same signed URL: X-Cache MISS, then HIT
```

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
