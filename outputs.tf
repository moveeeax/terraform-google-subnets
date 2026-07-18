output "id" {
  description = "Identifier of the subnetwork."
  value       = google_compute_subnetwork.this.id
}

output "self_link" {
  description = "URI of the subnetwork."
  value       = google_compute_subnetwork.this.self_link
}

output "name" {
  description = "Name of the subnetwork."
  value       = google_compute_subnetwork.this.name
}

output "ip_cidr_range" {
  description = "Primary IPv4 CIDR range of the subnetwork."
  value       = google_compute_subnetwork.this.ip_cidr_range
}

output "gateway_address" {
  description = "Gateway IP address of the subnetwork."
  value       = google_compute_subnetwork.this.gateway_address
}
