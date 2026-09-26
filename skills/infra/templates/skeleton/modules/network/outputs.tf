output "network_id" {
  description = "Fully qualified network id, for firewall rules and cluster configs."
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "Network name."
  value       = google_compute_network.this.name
}

output "network_self_link" {
  description = "Network self link, for resources that take a self link rather than an id."
  value       = google_compute_network.this.self_link
}

output "subnet_ids" {
  description = "Subnet ids keyed by subnet name."
  value       = { for k, s in google_compute_subnetwork.this : k => s.id }
}

output "subnet_self_links" {
  description = "Subnet self links keyed by subnet name."
  value       = { for k, s in google_compute_subnetwork.this : k => s.self_link }
}

output "subnet_secondary_ranges" {
  description = "Secondary range names keyed by subnet name, for GKE ip allocation."
  value       = { for k, s in google_compute_subnetwork.this : k => [for r in s.secondary_ip_range : r.range_name] }
}

output "nat_name" {
  description = "Cloud NAT name, or null when NAT is disabled."
  value       = var.enable_nat ? google_compute_router_nat.this[0].name : null
}
