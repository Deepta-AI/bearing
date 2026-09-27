resource "google_service_account" "main" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = var.account_id
}

resource "google_project_iam_member" "project" {
  for_each = toset(var.project_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.main.email}"
}
