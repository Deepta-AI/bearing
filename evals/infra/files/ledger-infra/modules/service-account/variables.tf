variable "project_id" {
  type        = string
  description = "Project that owns the service account."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a Google Cloud project id."
  }
}

variable "account_id" {
  type        = string
  description = "Service account id, for example ledger-api."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.account_id))
    error_message = "account_id must be 6 to 30 lowercase letters, digits or hyphens."
  }
}

variable "project_roles" {
  type        = list(string)
  description = "Roles granted to the account on the whole project. Prefer resource-level grants where the resource supports them."
  default     = []
  validation {
    condition     = alltrue([for r in var.project_roles : !contains(["roles/owner", "roles/editor"], r)])
    error_message = "roles/owner and roles/editor are not allowed."
  }
}
