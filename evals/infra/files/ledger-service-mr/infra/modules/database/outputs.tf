output "connection_name" {
  description = "Cloud SQL connection name, for the proxy sidecar."
  value       = google_sql_database_instance.main.connection_name
}

output "private_ip" {
  description = "Private IP of the instance."
  value       = google_sql_database_instance.main.private_ip_address
}
