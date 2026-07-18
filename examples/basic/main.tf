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
  name                    = "example-subnet-network"
  auto_create_subnetworks = false
}

module "subnet" {
  source = "../.."

  project_id    = var.project_id
  name          = "example-subnet"
  network       = google_compute_network.example.self_link
  region        = var.region
  ip_cidr_range = "10.20.0.0/24"

  secondary_ip_ranges = {
    pods     = "10.21.0.0/16"
    services = "10.22.0.0/20"
  }
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
  value = module.subnet.id
}
