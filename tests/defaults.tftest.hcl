mock_provider "google" {}

variables {
  project_id = "test-project"
  keys_secret = {
    id      = "test-key-secret"
    version = "latest"
  }
  salts_secret = {
    id      = "test-salt-secret"
    version = "latest"
  }
}

run "default_service_name" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.main.name == "imgproxy"
    error_message = "Service name must equal service_name default"
  }
}

run "default_deletion_protection" {
  command = plan

  assert {
    condition     = google_cloud_run_v2_service.main.deletion_protection == false
    error_message = "deletion_protection must default to false so terraform destroy works out of the box"
  }
}

run "community_image_url" {
  command = plan

  variables {
    tag = "v3.27.0"
  }

  assert {
    condition     = google_artifact_registry_repository.ghcr[0].repository_id == "imgproxy-ghcr"
    error_message = "Community mode must create the ghcr remote repo"
  }

  assert {
    condition     = length(google_artifact_registry_repository.pro) == 0
    error_message = "Community mode must not create the pro repo"
  }
}

run "pro_image_url" {
  command = plan

  variables {
    tag = "v3.27.0"
    pro = true
    pro_license_key_secret = {
      id      = "test-license-key-secret"
      version = "latest"
    }
    pro_registry_password_secret = {
      id      = "test-registry-password-secret"
      version = "latest"
    }
  }

  assert {
    condition     = google_artifact_registry_repository.pro[0].repository_id == "imgproxy-pro"
    error_message = "Pro mode must create the pro remote repo"
  }
}

run "custom_prefix_propagates" {
  command = plan

  variables {
    service_name = "myapp"
  }

  assert {
    condition     = google_cloud_run_v2_service.main.name == "myapp"
    error_message = "Service name must reflect service_name"
  }

  assert {
    condition     = google_service_account.imgproxy[0].account_id == "myapp-sa"
    error_message = "Service account ID must use service_name"
  }

  assert {
    condition     = google_secret_manager_secret_iam_member.cloud_run["test-key-secret"].secret_id == "test-key-secret"
    error_message = "Cloud Run SA must be granted access to keys secret"
  }

  assert {
    condition     = google_secret_manager_secret_iam_member.cloud_run["test-salt-secret"].secret_id == "test-salt-secret"
    error_message = "Cloud Run SA must be granted access to salts secret"
  }
}

run "custom_service_account_skips_creation" {
  command = plan

  variables {
    service_account = "existing-sa@test-project.iam.gserviceaccount.com"
  }

  assert {
    condition     = length(google_service_account.imgproxy) == 0
    error_message = "Providing service_account must skip SA creation"
  }
}

run "custom_image_override" {
  command = plan

  variables {
    repo = "gcr.io/my-project/custom-imgproxy"
    tag  = "v1.0.0"
  }

  assert {
    condition     = length(google_artifact_registry_repository.ghcr) == 0
    error_message = "Custom image should skip creating ghcr repo"
  }

  assert {
    condition     = length(google_artifact_registry_repository.pro) == 0
    error_message = "Custom image should skip creating pro repo"
  }
}

run "cdn_disabled_by_default" {
  command = plan

  assert {
    condition     = length(google_compute_global_address.cdn) == 0
    error_message = "CDN must not create resources when disabled"
  }
}

run "cdn_with_managed_cert" {
  command = plan

  variables {
    enable_cdn  = true
    cdn_domains = ["cdn.example.com"]
  }

  assert {
    condition     = length(google_compute_global_address.cdn) == 1
    error_message = "CDN must create a global static IP"
  }

  assert {
    condition     = google_compute_global_address.cdn[0].name == "imgproxy-cdn-ip"
    error_message = "CDN IP name must use service_name prefix"
  }

  assert {
    condition     = length(google_compute_managed_ssl_certificate.cdn) == 1
    error_message = "CDN must create managed cert when cdn_domains provided"
  }

  assert {
    condition     = google_cloud_run_v2_service.main.ingress == "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    error_message = "CDN must force ingress to INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  }

  assert {
    condition     = length(google_compute_url_map.cdn_http_redirect) == 1
    error_message = "CDN must create HTTP redirect URL map by default"
  }
}

run "cdn_with_existing_cert" {
  command = plan

  variables {
    enable_cdn           = true
    cdn_ssl_certificates = ["projects/test-project/global/sslCertificates/my-cert"]
  }

  assert {
    condition     = length(google_compute_global_address.cdn) == 1
    error_message = "CDN must create global address"
  }

  assert {
    condition     = length(google_compute_managed_ssl_certificate.cdn) == 0
    error_message = "CDN must not create managed cert when cdn_ssl_certificates provided"
  }
}

run "cdn_no_redirect" {
  command = plan

  variables {
    enable_cdn                 = true
    cdn_domains                = ["cdn.example.com"]
    cdn_redirect_http_to_https = false
  }

  assert {
    condition     = length(google_compute_url_map.cdn_http_redirect) == 0
    error_message = "HTTP redirect URL map must not be created when redirect disabled"
  }

  assert {
    condition     = length(google_compute_target_http_proxy.cdn_http) == 1
    error_message = "Direct HTTP proxy must be created when redirect disabled"
  }
}

run "timeout_sets_env_var_and_cdn" {
  command = plan

  variables {
    timeout     = 120
    enable_cdn  = true
    cdn_domains = ["cdn.example.com"]
  }

  assert {
    condition     = length([for e in google_cloud_run_v2_service.main.template[0].containers[0].env : e if e.name == "IMGPROXY_TIMEOUT" && e.value == "120"]) == 1
    error_message = "IMGPROXY_TIMEOUT must be set to the timeout value"
  }

  assert {
    condition     = google_compute_backend_service.cdn[0].timeout_sec == 120
    error_message = "CDN backend timeout_sec must match var.timeout"
  }
}

run "timeout_null_uses_cdn_default" {
  command = plan

  variables {
    enable_cdn  = true
    cdn_domains = ["cdn.example.com"]
  }

  assert {
    condition     = length([for e in google_cloud_run_v2_service.main.template[0].containers[0].env : e if e.name == "IMGPROXY_TIMEOUT"]) == 0
    error_message = "IMGPROXY_TIMEOUT must not be set when timeout is null"
  }

  assert {
    condition     = google_compute_backend_service.cdn[0].timeout_sec == 30
    error_message = "CDN backend timeout_sec must default to 30 when timeout is null"
  }
}

run "cdn_http_only_without_cert" {
  command = plan

  variables {
    enable_cdn                 = true
    cdn_redirect_http_to_https = false
  }

  # The warning check fires by design when no certificate is configured
  expect_failures = [check.cdn_without_certificate]

  assert {
    condition     = length(google_compute_target_https_proxy.cdn) == 0 && length(google_compute_global_forwarding_rule.cdn) == 0
    error_message = "HTTPS proxy and forwarding rule must not be created without a certificate"
  }

  assert {
    condition     = length(google_compute_global_forwarding_rule.cdn_http) == 1
    error_message = "HTTP forwarding rule must be created"
  }
}
