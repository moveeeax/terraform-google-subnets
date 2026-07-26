# Unit tests for the module. These run entirely offline against a mocked
# provider — no credentials, no API calls, no cost.
#
# `mock_provider` needs Terraform >= 1.7 / OpenTofu >= 1.7. That is a
# requirement of the test harness only; the module itself still supports the
# >= 1.5 declared in versions.tf, so do not raise required_version for this.

mock_provider "google" {}

variables {
  project_id    = "test-project"
  name          = "test-subnet"
  network       = "projects/test-project/global/networks/test-network"
  region        = "us-central1"
  ip_cidr_range = "10.20.0.0/24"
}

run "defaults_enable_flow_logs" {
  command = plan

  assert {
    condition     = length(google_compute_subnetwork.this.log_config) == 1
    error_message = "VPC flow logs must be enabled by default; the Compute API leaves them off."
  }

  assert {
    condition     = google_compute_subnetwork.this.log_config[0].aggregation_interval == "INTERVAL_5_SEC"
    error_message = "Default flow log aggregation interval should be INTERVAL_5_SEC."
  }

  assert {
    condition     = google_compute_subnetwork.this.log_config[0].metadata == "INCLUDE_ALL_METADATA"
    error_message = "Default flow log metadata should be INCLUDE_ALL_METADATA."
  }

  assert {
    condition     = output.flow_logs_enabled
    error_message = "flow_logs_enabled output should be true by default."
  }
}

run "defaults_enable_private_google_access" {
  command = plan

  assert {
    condition     = google_compute_subnetwork.this.private_ip_google_access
    error_message = "Private Google Access must default to on; without it VMs with no external IP cannot reach Google APIs at all."
  }

  assert {
    condition     = google_compute_subnetwork.this.purpose == "PRIVATE"
    error_message = "Default purpose should be PRIVATE."
  }

  assert {
    condition     = google_compute_subnetwork.this.role == null
    error_message = "A PRIVATE subnetwork must not carry a role."
  }
}

run "flow_logs_can_be_tuned" {
  command = plan

  variables {
    flow_logs = {
      aggregation_interval = "INTERVAL_15_MIN"
      flow_sampling        = 0.1
      metadata             = "CUSTOM_METADATA"
      metadata_fields      = ["src_instance", "dest_instance"]
      filter_expr          = "true"
    }
  }

  assert {
    condition     = google_compute_subnetwork.this.log_config[0].flow_sampling == 0.1
    error_message = "flow_sampling should be passed through to log_config."
  }

  assert {
    condition     = toset(google_compute_subnetwork.this.log_config[0].metadata_fields) == toset(["src_instance", "dest_instance"])
    error_message = "metadata_fields should be passed through when metadata is CUSTOM_METADATA."
  }
}

run "flow_logs_metadata_fields_dropped_unless_custom" {
  command = plan

  variables {
    flow_logs = {
      metadata        = "INCLUDE_ALL_METADATA"
      metadata_fields = ["src_instance"]
    }
  }

  assert {
    condition     = google_compute_subnetwork.this.log_config[0].metadata_fields == null
    error_message = "metadata_fields is only valid with CUSTOM_METADATA and must otherwise be dropped, or the API rejects the request."
  }
}

run "flow_logs_can_be_disabled" {
  command = plan

  variables {
    flow_logs = { enabled = false }
  }

  assert {
    condition     = length(google_compute_subnetwork.this.log_config) == 0
    error_message = "Setting flow_logs.enabled = false must remove the log_config block."
  }
}

run "secondary_ranges_are_exposed" {
  command = plan

  variables {
    secondary_ip_ranges = {
      pods     = "10.21.0.0/16"
      services = "10.22.0.0/20"
    }
  }

  assert {
    condition     = length(google_compute_subnetwork.this.secondary_ip_range) == 2
    error_message = "Both secondary ranges should reach the resource."
  }

  assert {
    condition     = output.secondary_ip_ranges == { pods = "10.21.0.0/16", services = "10.22.0.0/20" }
    error_message = "secondary_ip_ranges output should map range names to their CIDRs."
  }
}

run "proxy_only_subnet_drops_unsupported_features" {
  command = plan

  variables {
    purpose = "REGIONAL_MANAGED_PROXY"
    role    = "ACTIVE"
  }

  assert {
    condition     = length(google_compute_subnetwork.this.log_config) == 0
    error_message = "A proxy-only subnet cannot emit flow logs; the module must not send a log_config block."
  }

  assert {
    condition     = google_compute_subnetwork.this.private_ip_google_access == false
    error_message = "A proxy-only subnet cannot enable Private Google Access; the module must force it off."
  }

  assert {
    condition     = google_compute_subnetwork.this.role == "ACTIVE"
    error_message = "role should be passed through for a proxy-only subnet."
  }
}

run "private_service_connect_subnet_drops_unsupported_features" {
  command = plan

  variables {
    purpose = "PRIVATE_SERVICE_CONNECT"
  }

  assert {
    condition     = length(google_compute_subnetwork.this.log_config) == 0
    error_message = "A Private Service Connect subnet cannot emit flow logs."
  }

  assert {
    condition     = google_compute_subnetwork.this.private_ip_google_access == false
    error_message = "A Private Service Connect subnet cannot enable Private Google Access."
  }
}

# --- input validation -------------------------------------------------------

run "rejects_malformed_primary_cidr" {
  command = plan

  variables {
    ip_cidr_range = "10.20.0.0"
  }

  expect_failures = [var.ip_cidr_range]
}

run "rejects_ipv6_primary_cidr" {
  command = plan

  variables {
    ip_cidr_range = "2600:1900::/28"
  }

  expect_failures = [var.ip_cidr_range]
}

run "rejects_primary_cidr_with_host_bits_set" {
  command = plan

  variables {
    ip_cidr_range = "10.20.0.5/24"
  }

  expect_failures = [var.ip_cidr_range]
}

run "rejects_primary_cidr_smaller_than_29" {
  command = plan

  variables {
    ip_cidr_range = "10.20.0.0/30"
  }

  expect_failures = [var.ip_cidr_range]
}

run "rejects_malformed_secondary_cidr" {
  command = plan

  variables {
    secondary_ip_ranges = { pods = "10.21.0.0/notaprefix" }
  }

  expect_failures = [var.secondary_ip_ranges]
}

run "rejects_secondary_cidr_with_host_bits_set" {
  command = plan

  variables {
    secondary_ip_ranges = { pods = "10.21.0.1/16" }
  }

  expect_failures = [var.secondary_ip_ranges]
}

run "rejects_invalid_secondary_range_name" {
  command = plan

  variables {
    secondary_ip_ranges = { "Pods_Range" = "10.21.0.0/16" }
  }

  expect_failures = [var.secondary_ip_ranges]
}

run "rejects_invalid_subnet_name" {
  command = plan

  variables {
    name = "Not_A_Valid_Name"
  }

  expect_failures = [var.name]
}

run "rejects_unknown_purpose" {
  command = plan

  variables {
    purpose = "PRIVATE_SERVICE_CONNECTION"
  }

  expect_failures = [var.purpose]
}

run "rejects_unknown_role" {
  command = plan

  variables {
    purpose = "REGIONAL_MANAGED_PROXY"
    role    = "STANDBY"
  }

  expect_failures = [var.role]
}

run "rejects_zero_flow_sampling" {
  command = plan

  variables {
    flow_logs = { flow_sampling = 0 }
  }

  expect_failures = [var.flow_logs]
}

run "rejects_custom_metadata_without_fields" {
  command = plan

  variables {
    flow_logs = { metadata = "CUSTOM_METADATA" }
  }

  expect_failures = [var.flow_logs]
}

# --- cross-field preconditions ----------------------------------------------

run "rejects_secondary_range_overlapping_primary" {
  command = plan

  variables {
    ip_cidr_range       = "10.20.0.0/16"
    secondary_ip_ranges = { pods = "10.20.128.0/20" }
  }

  expect_failures = [google_compute_subnetwork.this]
}

run "rejects_overlapping_secondary_ranges" {
  command = plan

  variables {
    secondary_ip_ranges = {
      pods     = "10.21.0.0/16"
      services = "10.21.4.0/22"
    }
  }

  expect_failures = [google_compute_subnetwork.this]
}

run "accepts_adjacent_non_overlapping_ranges" {
  command = plan

  variables {
    ip_cidr_range = "10.20.0.0/24"
    secondary_ip_ranges = {
      pods     = "10.20.1.0/24"
      services = "10.20.2.0/24"
    }
  }

  assert {
    condition     = length(google_compute_subnetwork.this.secondary_ip_range) == 2
    error_message = "Adjacent but non-overlapping ranges must be accepted."
  }
}

run "rejects_proxy_only_subnet_without_role" {
  command = plan

  variables {
    purpose = "REGIONAL_MANAGED_PROXY"
  }

  expect_failures = [google_compute_subnetwork.this]
}

run "rejects_role_on_private_subnet" {
  command = plan

  variables {
    purpose = "PRIVATE"
    role    = "ACTIVE"
  }

  expect_failures = [google_compute_subnetwork.this]
}

run "rejects_secondary_ranges_on_reserved_purpose" {
  command = plan

  variables {
    purpose             = "PRIVATE_SERVICE_CONNECT"
    secondary_ip_ranges = { pods = "10.21.0.0/16" }
  }

  expect_failures = [google_compute_subnetwork.this]
}
