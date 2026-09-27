output "email" {
  description = "Email of the service account."
  value       = google_service_account.main.email
}

output "member" {
  description = "IAM member string for the service account."
  value       = "serviceAccount:${google_service_account.main.email}"
}
