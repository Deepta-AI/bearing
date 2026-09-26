output "email" {
  description = "Service account email, the value most other resources take."
  value       = google_service_account.this.email
}

output "id" {
  description = "Fully qualified service account id (projects/.../serviceAccounts/...)."
  value       = google_service_account.this.name
}

output "member" {
  description = "IAM member string, serviceAccount:<email>, for bindings elsewhere."
  value       = "serviceAccount:${google_service_account.this.email}"
}
