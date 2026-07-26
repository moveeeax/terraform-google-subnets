locals {
  # Purposes that reserve the subnet for a Google-managed control plane rather
  # than for customer VMs. The Compute API rejects Private Google Access, VPC
  # flow logs and secondary IP ranges on these, so the module keeps them off
  # instead of letting the request fail at apply time.
  reserved_purposes = [
    "REGIONAL_MANAGED_PROXY",
    "GLOBAL_MANAGED_PROXY",
    "PRIVATE_SERVICE_CONNECT",
    "PRIVATE_NAT",
  ]
  is_reserved_purpose = contains(local.reserved_purposes, var.purpose)

  # Envoy proxy-only subnets are the only purposes that take (and require) a role.
  proxy_purposes  = ["REGIONAL_MANAGED_PROXY", "GLOBAL_MANAGED_PROXY"]
  is_proxy_subnet = contains(local.proxy_purposes, var.purpose)

  # Purposes for which the API explicitly rejects a role.
  roleless_purposes = ["PRIVATE", "PRIVATE_SERVICE_CONNECT", "PRIVATE_NAT"]

  private_ip_google_access = local.is_reserved_purpose ? false : var.private_ip_google_access
  flow_logs_enabled        = local.is_reserved_purpose ? false : var.flow_logs.enabled

  # Every range this module hands to the API, primary and secondary. The
  # "<primary>" key cannot collide with a secondary range name because range
  # names are validated against RFC 1035 and so cannot contain angle brackets.
  cidr_ranges = merge(
    { "<primary>" = var.ip_cidr_range },
    var.secondary_ip_ranges,
  )
  cidr_range_names = sort(keys(local.cidr_ranges))

  # Two CIDRs overlap iff their network addresses are equal once both are masked
  # to the shorter of the two prefix lengths. Google rejects overlapping ranges
  # on a subnetwork, but only once the request is in flight; catching it here
  # turns a failed apply into a plan-time error.
  overlapping_cidr_ranges = flatten([
    for i, a in local.cidr_range_names : [
      for j, b in local.cidr_range_names :
      format(
        "%s (%s) overlaps %s (%s)",
        a, local.cidr_ranges[a], b, local.cidr_ranges[b],
      )
      if j > i && cidrhost(
        format("%s/%d", cidrhost(local.cidr_ranges[a], 0), min(
          tonumber(split("/", local.cidr_ranges[a])[1]),
          tonumber(split("/", local.cidr_ranges[b])[1]),
        )), 0
        ) == cidrhost(
        format("%s/%d", cidrhost(local.cidr_ranges[b], 0), min(
          tonumber(split("/", local.cidr_ranges[a])[1]),
          tonumber(split("/", local.cidr_ranges[b])[1]),
        )), 0
      )
    ]
  ])
}

resource "google_compute_subnetwork" "this" {
  project                  = var.project_id
  name                     = var.name
  network                  = var.network
  region                   = var.region
  ip_cidr_range            = var.ip_cidr_range
  private_ip_google_access = local.private_ip_google_access
  description              = var.description
  purpose                  = var.purpose
  role                     = var.role

  dynamic "secondary_ip_range" {
    for_each = var.secondary_ip_ranges
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }

  # VPC flow logs are off by default in the Compute API. Without them there is
  # no record of accepted or denied traffic on the subnet, which is the one
  # thing you need during an incident, so this module turns them on.
  dynamic "log_config" {
    for_each = local.flow_logs_enabled ? [var.flow_logs] : []
    content {
      aggregation_interval = log_config.value.aggregation_interval
      flow_sampling        = log_config.value.flow_sampling
      metadata             = log_config.value.metadata
      metadata_fields      = log_config.value.metadata == "CUSTOM_METADATA" ? log_config.value.metadata_fields : null
      filter_expr          = log_config.value.filter_expr
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.overlapping_cidr_ranges) == 0
      error_message = "IP ranges on a subnetwork must not overlap each other: ${join("; ", local.overlapping_cidr_ranges)}."
    }

    precondition {
      condition     = local.is_reserved_purpose ? length(var.secondary_ip_ranges) == 0 : true
      error_message = "secondary_ip_ranges is not supported when purpose is \"${var.purpose}\"; only subnets that carry customer VMs may have secondary ranges."
    }

    precondition {
      condition     = local.is_proxy_subnet ? var.role != null : true
      error_message = "role must be set to \"ACTIVE\" or \"BACKUP\" when purpose is \"${var.purpose}\"; Google rejects a proxy-only subnet without a role."
    }

    precondition {
      condition     = contains(local.roleless_purposes, var.purpose) ? var.role == null : true
      error_message = "role must not be set when purpose is \"${var.purpose}\"; it only applies to proxy-only subnets."
    }
  }
}
