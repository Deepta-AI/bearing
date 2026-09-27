variable "project_id" {
  type        = string
  description = "Google Cloud project of this environment."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a Google Cloud project id."
  }
}

variable "region" {
  type        = string
  description = "Region for every regional resource (ADR-0001)."
  default     = "asia-south1"
  validation {
    condition     = var.region == "asia-south1"
    error_message = "ADR-0001: ledger infrastructure runs in asia-south1 only."
  }
}
