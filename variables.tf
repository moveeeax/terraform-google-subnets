variable "project_id" {
  description = "ID of the project in which to create the subnetwork."
  type        = string
}

variable "name" {
  description = "Name of the subnetwork."
  type        = string
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
  description = "Primary IPv4 CIDR range of the subnetwork."
  type        = string
}

variable "private_ip_google_access" {
  description = "Whether VMs without external IPs can reach Google APIs and services."
  type        = bool
  default     = true
}

variable "secondary_ip_ranges" {
  description = "Secondary IP ranges, e.g. for GKE pods and services, keyed by range name."
  type        = map(string)
  default     = {}
}

variable "description" {
  description = "Optional description for the subnetwork."
  type        = string
  default     = null
}
