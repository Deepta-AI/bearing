# Service account with project roles and an optional workload identity
# binding. No key is ever created here: workloads use workload identity,
# CI uses workload identity federation.
#
# AWS equivalent: aws_iam_role with an assume-role policy for the pod's
# service account (IRSA) plus aws_iam_role_policy_attachment per policy.

resource "google_service_account" "this" {
  account_id   = var.account_id
  display_name = var.display_name
  project      = var.project
  description  = "Managed by Terraform (__REPO_NAME__)"
}

resource "google_project_iam_member" "this" {
  for_each = toset(var.roles)

  project = var.project
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}

# Lets the named Kubernetes service account act as this Google account.
resource "google_service_account_iam_member" "workload_identity" {
  count = var.workload_identity_user == null ? 0 : 1

  service_account_id = google_service_account.this.name
  role               = "roles/iam.workloadIdentityUser"
  member             = var.workload_identity_user
}
