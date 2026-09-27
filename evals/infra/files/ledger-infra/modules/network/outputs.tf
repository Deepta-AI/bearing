output "network_id" {
  description = "Id of the VPC."
  value       = google_compute_network.main.id
}

output "network_name" {
  description = "Name of the VPC."
  value       = google_compute_network.main.name
}

output "subnet_id" {
  description = "Id of the GKE subnet."
  value       = google_compute_subnetwork.gke.id
}
