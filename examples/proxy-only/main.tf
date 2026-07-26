terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "example" {
  project                 = var.project_id
  name                    = "example-proxy-network"
  auto_create_subnetworks = false
}

# A proxy-only subnet backs regional Envoy-based load balancers. It carries no
# customer VMs, so Google rejects Private Google Access, VPC flow logs and
# secondary ranges on it, and requires a role. The module handles the first
# three for you and fails the plan if the role is missing.
module "proxy_only_subnet" {
  source = "../.."

  project_id    = var.project_id
  name          = "example-proxy-only-subnet"
  network       = google_compute_network.example.self_link
  region        = var.region
  ip_cidr_range = "10.30.0.0/24"
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

variable "project_id" {
  description = "Project ID to deploy the example subnetwork into."
  type        = string
}

variable "region" {
  description = "Region for the google provider and subnetwork."
  type        = string
  default     = "us-central1"
}

output "subnet_id" {
  value = module.proxy_only_subnet.id
}

output "flow_logs_enabled" {
  description = "False: a proxy-only subnet cannot emit flow logs."
  value       = module.proxy_only_subnet.flow_logs_enabled
}
