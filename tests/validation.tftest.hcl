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

run "rejects_invalid_ingress" {
  command = plan

  variables {
    ingress = "INVALID_VALUE"
  }

  expect_failures = [var.ingress]
}

run "rejects_invalid_launch_stage" {
  command = plan

  variables {
    launch_stage = "INVALID_VALUE"
  }

  expect_failures = [var.launch_stage]
}

run "rejects_pro_without_registry_password" {
  command = plan

  variables {
    pro = true
  }

  expect_failures = [
    google_service_account.imgproxy,
    google_artifact_registry_repository.pro,
  ]
}

run "rejects_secure_mode_without_keys" {
  command = plan

  variables {
    keys_secret  = null
    salts_secret = null
  }

  # The common module repeats this check; mock it so only the root precondition is evaluated.
  override_module {
    target = module.imgproxy_common
    outputs = {
      image             = "mock"
      workers           = 1
      env_vars          = {}
      env_secret_vars   = []
      cdn_cache_headers = []
      cdn_cache_cookies = []
    }
  }

  expect_failures = [google_service_account.imgproxy]
}

run "rejects_secure_mode_without_salts" {
  command = plan

  variables {
    salts_secret = null
  }

  # The common module repeats this check; mock it so only the root precondition is evaluated.
  override_module {
    target = module.imgproxy_common
    outputs = {
      image             = "mock"
      workers           = 1
      env_vars          = {}
      env_secret_vars   = []
      cdn_cache_headers = []
      cdn_cache_cookies = []
    }
  }

  expect_failures = [google_service_account.imgproxy]
}

run "rejects_cdn_with_secret_secret_id" {
  command = plan

  variables {
    enable_cdn  = true
    cdn_domains = ["cdn.example.com"]
    secret_secret = {
      id      = "projects/test-project/secrets/imgproxy-secret"
      version = "latest"
    }
  }

  expect_failures = [google_cloud_run_v2_service.main]
}

run "rejects_cdn_without_cert_with_https_redirect" {
  command = plan

  variables {
    enable_cdn = true
  }

  expect_failures = [google_cloud_run_v2_service.main, check.cdn_without_certificate]
}

run "rejects_cdn_with_both_cert_types" {
  command = plan

  variables {
    enable_cdn           = true
    cdn_domains          = ["cdn.example.com"]
    cdn_ssl_certificates = ["projects/test-project/global/sslCertificates/my-cert"]
  }

  expect_failures = [google_cloud_run_v2_service.main]
}

run "rejects_invalid_cdn_cache_mode" {
  command = plan

  variables {
    enable_cdn     = true
    cdn_domains    = ["cdn.example.com"]
    cdn_cache_mode = "INVALID_MODE"
  }

  expect_failures = [var.cdn_cache_mode]
}
