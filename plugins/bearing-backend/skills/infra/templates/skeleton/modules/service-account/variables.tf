variable "account_id" {
  description = "Service account id (the part before @). 6 to 30 lowercase characters, digits and hyphens."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.account_id))
    error_message = "account_id must match ^[a-z][a-z0-9-]{4,28}[a-z0-9]$."
  }
}

variable "display_name" {
  description = "Human readable name shown in the console."
  type        = string

  validation {
    condition     = length(var.display_name) > 0 && length(var.display_name) <= 100
    error_message = "display_name must be 1 to 100 characters."
  }
}

variable "project" {
  description = "Google Cloud project id that owns the account and receives the role bindings."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project))
    error_message = "project must be a valid Google Cloud project id."
  }
}

variable "roles" {
  description = "Project-level roles to grant. Least privilege: primitive roles are refused; prefer resource-level bindings where the provider offers them."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for r in var.roles : startswith(r, "roles/") || startswith(r, "projects/") || startswith(r, "organizations/")])
    error_message = "every role must be a predefined (roles/...) or custom (projects/.../roles/...) role."
  }

  validation {
    condition     = alltrue([for r in var.roles : !contains(["roles/owner", "roles/editor", "roles/viewer"], r)])
    error_message = "roles/owner, roles/editor and roles/viewer are primitive roles and are not granted by this module."
  }
}

variable "workload_identity_user" {
  description = "Kubernetes principal allowed to impersonate this account, as serviceAccount:PROJECT.svc.id.goog[NAMESPACE/KSA]. Null for none."
  type        = string
  default     = null

  validation {
    condition     = var.workload_identity_user == null || can(regex("^serviceAccount:[a-z0-9-]+\\.svc\\.id\\.goog\\[[a-z0-9-]+/[a-z0-9-]+\\]$", var.workload_identity_user))
    error_message = "workload_identity_user must look like serviceAccount:PROJECT.svc.id.goog[NAMESPACE/KSA]."
  }
}
