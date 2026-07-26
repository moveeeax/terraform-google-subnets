variable "project_id" {
  description = "ID of the project in which to create the subnetwork."
  type        = string
}

variable "name" {
  description = "Name of the subnetwork."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.name))
    error_message = "name must be a valid RFC 1035 resource name: 1-63 characters, lowercase letters, digits or hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "network" {
  description = "Self link or name of the VPC network this subnetwork belongs to."
  type        = string
}

variable "region" {
  description = "Region in which to create the subnetwork."
  type        = string
}

variable "ip_cidr_range" {
  description = "Primary IPv4 CIDR range of the subnetwork, e.g. \"10.20.0.0/24\"."
  type        = string

  validation {
    condition = can(cidrhost(var.ip_cidr_range, 0)) && can(regex(
      "^([0-9]{1,3}\\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$", var.ip_cidr_range
    ))
    error_message = "ip_cidr_range must be a valid IPv4 CIDR block in a.b.c.d/prefix form, e.g. \"10.20.0.0/24\". Google Cloud subnetworks do not take an IPv6 primary range."
  }

  validation {
    condition     = try(cidrhost(var.ip_cidr_range, 0) == split("/", var.ip_cidr_range)[0], false)
    error_message = "ip_cidr_range must be the network address of its block (no host bits set); Google Cloud rejects ranges such as \"10.20.0.5/24\"."
  }

  validation {
    condition     = try(tonumber(split("/", var.ip_cidr_range)[1]) <= 29, false)
    error_message = "ip_cidr_range must be /29 or larger. Google Cloud reserves four addresses in every subnetwork, so a /30, /31 or /32 has no usable addresses and is rejected."
  }
}

variable "private_ip_google_access" {
  description = "Whether VMs without external IPs can reach Google APIs and services. Forced off for purposes that reserve the subnet for a Google-managed control plane, where the API rejects it."
  type        = bool
  default     = true
}

variable "secondary_ip_ranges" {
  description = "Secondary IP ranges, e.g. for GKE pods and services, keyed by range name."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for range_name in keys(var.secondary_ip_ranges) :
      can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", range_name))
    ])
    error_message = "Every secondary range name must be a valid RFC 1035 resource name: 1-63 characters, lowercase letters, digits or hyphens, starting with a letter and not ending with a hyphen."
  }

  validation {
    condition = alltrue([
      for cidr in values(var.secondary_ip_ranges) :
      can(cidrhost(cidr, 0)) && can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$", cidr))
    ])
    error_message = "Every secondary IP range must be a valid IPv4 CIDR block in a.b.c.d/prefix form, e.g. \"10.21.0.0/16\"."
  }

  validation {
    condition = alltrue([
      for cidr in values(var.secondary_ip_ranges) :
      try(cidrhost(cidr, 0) == split("/", cidr)[0], false)
    ])
    error_message = "Every secondary IP range must be the network address of its block (no host bits set)."
  }
}

variable "description" {
  description = "Optional description for the subnetwork."
  type        = string
  default     = null
}

variable "purpose" {
  description = "Purpose of the subnetwork. \"PRIVATE\" is an ordinary subnet for VMs; the proxy, Private Service Connect and NAT purposes reserve the range for a Google-managed control plane and accept neither secondary ranges, Private Google Access nor flow logs."
  type        = string
  default     = "PRIVATE"

  validation {
    condition = contains([
      "PRIVATE",
      "PEER_MIGRATION",
      "REGIONAL_MANAGED_PROXY",
      "GLOBAL_MANAGED_PROXY",
      "PRIVATE_SERVICE_CONNECT",
      "PRIVATE_NAT",
    ], var.purpose)
    error_message = "purpose must be one of PRIVATE, PEER_MIGRATION, REGIONAL_MANAGED_PROXY, GLOBAL_MANAGED_PROXY, PRIVATE_SERVICE_CONNECT or PRIVATE_NAT."
  }
}

variable "role" {
  description = "Role of a proxy-only subnetwork, \"ACTIVE\" or \"BACKUP\". Required when purpose is REGIONAL_MANAGED_PROXY or GLOBAL_MANAGED_PROXY, and rejected for the ordinary, Private Service Connect and NAT purposes."
  type        = string
  default     = null

  validation {
    condition     = var.role == null || contains(["ACTIVE", "BACKUP"], coalesce(var.role, "ACTIVE"))
    error_message = "role must be either \"ACTIVE\" or \"BACKUP\"."
  }
}

variable "flow_logs" {
  description = "VPC flow log settings for the subnetwork. Enabled by default; set enabled = false to opt out. Ignored for purposes that reserve the subnet for a Google-managed control plane, which cannot emit flow logs."
  type = object({
    enabled              = optional(bool, true)
    aggregation_interval = optional(string, "INTERVAL_5_SEC")
    flow_sampling        = optional(number, 0.5)
    metadata             = optional(string, "INCLUDE_ALL_METADATA")
    metadata_fields      = optional(list(string), null)
    filter_expr          = optional(string, null)
  })
  default = {}

  validation {
    condition = contains([
      "INTERVAL_5_SEC",
      "INTERVAL_30_SEC",
      "INTERVAL_1_MIN",
      "INTERVAL_5_MIN",
      "INTERVAL_10_MIN",
      "INTERVAL_15_MIN",
    ], var.flow_logs.aggregation_interval)
    error_message = "flow_logs.aggregation_interval must be one of INTERVAL_5_SEC, INTERVAL_30_SEC, INTERVAL_1_MIN, INTERVAL_5_MIN, INTERVAL_10_MIN or INTERVAL_15_MIN."
  }

  validation {
    condition     = var.flow_logs.flow_sampling > 0 && var.flow_logs.flow_sampling <= 1
    error_message = "flow_logs.flow_sampling must be greater than 0 and at most 1. Use enabled = false rather than a sampling rate of 0, which would leave flow logging switched on while dropping every record."
  }

  validation {
    condition     = contains(["INCLUDE_ALL_METADATA", "EXCLUDE_ALL_METADATA", "CUSTOM_METADATA"], var.flow_logs.metadata)
    error_message = "flow_logs.metadata must be one of INCLUDE_ALL_METADATA, EXCLUDE_ALL_METADATA or CUSTOM_METADATA."
  }

  validation {
    condition     = var.flow_logs.metadata == "CUSTOM_METADATA" ? try(length(var.flow_logs.metadata_fields), 0) > 0 : true
    error_message = "flow_logs.metadata_fields must list at least one field when flow_logs.metadata is CUSTOM_METADATA."
  }
}
