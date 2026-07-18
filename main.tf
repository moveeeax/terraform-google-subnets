resource "google_compute_subnetwork" "this" {
  project                  = var.project_id
  name                     = var.name
  network                  = var.network
  region                   = var.region
  ip_cidr_range            = var.ip_cidr_range
  private_ip_google_access = var.private_ip_google_access
  description              = var.description

  dynamic "secondary_ip_range" {
    for_each = var.secondary_ip_ranges
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }
}
