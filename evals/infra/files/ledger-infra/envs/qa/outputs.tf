output "network_id" {
  description = "Id of the environment VPC, read by the GKE cluster repository."
  value       = module.network.network_id
}

output "subnet_id" {
  description = "Id of the GKE subnet, read by the GKE cluster repository."
  value       = module.network.subnet_id
}

output "ledger_api_sa_email" {
  description = "Service account the ledger-api pods run as (workload identity)."
  value       = module.ledger_api_sa.email
}
