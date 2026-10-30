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

run "insecure_skips_key_iam" {
  command = plan

  variables {
    insecure     = true
    keys_secret  = null
    salts_secret = null
  }

  assert {
    condition     = !contains(keys(google_secret_manager_secret_iam_member.cloud_run), "test-key-secret")
    error_message = "keys IAM member must not be created in insecure mode"
  }

  assert {
    condition     = !contains(keys(google_secret_manager_secret_iam_member.cloud_run), "test-salt-secret")
    error_message = "salts IAM member must not be created in insecure mode"
  }
}

run "secure_mode_grants_key_iam" {
  command = plan

  assert {
    condition     = google_secret_manager_secret_iam_member.cloud_run["test-key-secret"].secret_id == "test-key-secret"
    error_message = "keys IAM member must be created in secure mode"
  }

  assert {
    condition     = google_secret_manager_secret_iam_member.cloud_run["test-salt-secret"].secret_id == "test-salt-secret"
    error_message = "salts IAM member must be created in secure mode"
  }
}

run "pro_grants_ar_iam" {
  command = plan

  variables {
    pro = true
    pro_license_key_secret = {
      id      = "test-license-key-secret"
      version = "latest"
    }
    repo_password_secret = {
      id      = "test-registry-password-secret"
      version = "latest"
    }
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_member.artifact_registry) == 1
    error_message = "AR service agent IAM member must be created when pro = true"
  }

  assert {
    condition     = google_secret_manager_secret_iam_member.artifact_registry[0].secret_id == "test-registry-password-secret"
    error_message = "AR IAM member must reference the pro registry password secret"
  }
}

run "secrets_map_grants_iam" {
  command = plan

  variables {
    secrets = {
      IMGPROXY_NEW_RELIC_KEY = { id = "projects/test-project/secrets/newrelic" }
    }
  }

  assert {
    condition     = google_secret_manager_secret_iam_member.cloud_run["projects/test-project/secrets/newrelic"].secret_id == "projects/test-project/secrets/newrelic"
    error_message = "secrets map entries must grant IAM access to Cloud Run SA"
  }
}

run "secrets_map_custom_version" {
  command = plan

  variables {
    secrets = {
      IMGPROXY_NEW_RELIC_KEY = { id = "projects/test-project/secrets/newrelic", version = "3" }
      IMGPROXY_SENTRY_DSN    = { id = "projects/test-project/secrets/sentry" }
    }
  }

  assert {
    condition     = length([for e in google_cloud_run_v2_service.main.template[0].containers[0].env : e if e.name == "IMGPROXY_NEW_RELIC_KEY" && try(e.value_source[0].secret_key_ref[0].version, "") == "3"]) == 1
    error_message = "custom version must be passed through to the container env"
  }

  assert {
    condition     = length([for e in google_cloud_run_v2_service.main.template[0].containers[0].env : e if e.name == "IMGPROXY_SENTRY_DSN" && try(e.value_source[0].secret_key_ref[0].version, "") == "latest"]) == 1
    error_message = "omitted version must default to latest"
  }
}

run "source_buckets_grants_viewer" {
  command = plan

  variables {
    source_buckets = ["my-imgproxy-source", "my-imgproxy-source-2"]
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.source) == 2
    error_message = "source_buckets must create one IAM binding per bucket"
  }

  assert {
    condition     = google_storage_bucket_iam_member.source["my-imgproxy-source"].bucket == "my-imgproxy-source"
    error_message = "source_buckets IAM binding must reference the correct bucket"
  }

  assert {
    condition     = google_storage_bucket_iam_member.source["my-imgproxy-source"].role == "roles/storage.objectViewer"
    error_message = "source_buckets IAM role must be objectViewer"
  }
}

run "cache_bucket_grants_admin" {
  command = plan

  variables {
    cache_bucket = "my-imgproxy-cache"
  }

  assert {
    condition     = length(google_storage_bucket_iam_member.cache) == 1
    error_message = "cache_bucket must create an IAM binding"
  }

  assert {
    condition     = google_storage_bucket_iam_member.cache[0].role == "roles/storage.objectAdmin"
    error_message = "cache_bucket IAM role must be objectAdmin"
  }
}

run "monitoring_creates_collector_config_and_iam" {
  command = plan

  variables {
    enable_monitoring = true
  }

  assert {
    condition     = length(google_secret_manager_secret.otel_collector_config) == 1
    error_message = "Monitoring must create OTEL collector config secret"
  }

  assert {
    condition     = length(google_project_iam_member.otel_trace) == 1 && length(google_project_iam_member.otel_metrics) == 1 && length(google_project_iam_member.otel_logs) == 1
    error_message = "Monitoring must grant Cloud Trace, Cloud Monitoring, and Cloud Logging IAM roles"
  }
}
