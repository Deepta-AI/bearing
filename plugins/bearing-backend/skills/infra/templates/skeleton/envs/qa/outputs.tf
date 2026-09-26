# Everything another repository consumes from qa is an output here.

output "network_id" {
  description = "VPC id for cluster and firewall configuration."
  value       = module.network.network_id
}

output "network_name" {
  description = "VPC name."
  value       = module.network.network_name
}

output "subnet_ids" {
  description = "Subnet ids keyed by name."
  value       = module.network.subnet_ids
}

output "subnet_secondary_ranges" {
  description = "Secondary range names per subnet, for GKE ip allocation."
  value       = module.network.subnet_secondary_ranges
}

output "app_service_account_email" {
  description = "Email of the application service account; the workload's Kubernetes service account annotates with it."
  value       = module.app_service_account.email
}
