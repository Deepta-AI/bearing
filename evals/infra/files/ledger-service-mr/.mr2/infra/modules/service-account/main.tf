resource "google_service_account" "main" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = var.account_id
}

# Authoritative per role, so a role taken out of project_roles is really
# revoked instead of lingering after state drift.
resource "google_project_iam_binding" "project" {
  for_each = toset(var.project_roles)
  project  = var.project_id
  role     = each.value
  members  = ["serviceAccount:${google_service_account.main.email}"]
}
