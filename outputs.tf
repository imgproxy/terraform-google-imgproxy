output "url" {
  description = "The imgproxy endpoint URL. When enable_cdn = true and cdn_domains is set, returns the first domain as HTTPS. When only cdn_ssl_certificates is provided, returns the static IP URL. Otherwise returns the Cloud Run service URL."
  value = var.enable_cdn ? (
    length(var.cdn_domains) > 0
    ? "https://${var.cdn_domains[0]}"
    : "https://${google_compute_global_address.cdn[0].address}"
  ) : google_cloud_run_v2_service.main.uri
}

output "service_name" {
  description = "The Cloud Run service name."
  value       = google_cloud_run_v2_service.main.name
}

output "service_account_email" {
  description = "Email of the imgproxy service account."
  value       = local.service_account_email
}

output "location" {
  description = "The region where the Cloud Run service is deployed. Use this to create a Serverless NEG when attaching a load balancer."
  value       = google_cloud_run_v2_service.main.location
}

output "cdn_ip_address" {
  description = "Static IP address of the CDN load balancer. Point your DNS A record to this IP."
  value       = var.enable_cdn ? google_compute_global_address.cdn[0].address : null
}

output "cdn_managed_certificate_id" {
  description = "ID of the managed SSL certificate. Check status in Cloud Console under Load Balancing > Certificates."
  value       = var.enable_cdn && length(var.cdn_domains) > 0 ? google_compute_managed_ssl_certificate.cdn[0].id : null
}
