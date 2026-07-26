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

output "secondary_ip_ranges" {
  description = "Secondary IP ranges of the subnetwork, keyed by range name. Handy for wiring a GKE cluster to its pod and service ranges."
  value       = { for range in google_compute_subnetwork.this.secondary_ip_range : range.range_name => range.ip_cidr_range }
}

output "flow_logs_enabled" {
  description = "Whether VPC flow logs are enabled on the subnetwork. False when flow_logs.enabled is false or the subnetwork's purpose cannot emit flow logs."
  value       = local.flow_logs_enabled
}
