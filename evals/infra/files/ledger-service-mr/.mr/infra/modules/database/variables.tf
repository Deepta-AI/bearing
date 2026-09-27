variable "env" {
  type        = string
  description = "Environment name, used in resource names."
  validation {
    condition     = contains(["dev", "qa", "prod"], var.env)
    error_message = "dev, qa or prod."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Cloud SQL deletion protection. Off so the rename to ledger-<env>-db can go through; turn back on in a follow-up."
  default     = false
}

variable "region" {
  type        = string
  description = "Region of the instance and of its backups (ADR: asia-south1 only)."
  validation {
    condition     = var.region == "asia-south1"
    error_message = "asia-south1 only."
  }
}

variable "network_id" {
  type        = string
  description = "VPC the instance joins over private IP."
}

variable "tier" {
  type        = string
  description = "Machine tier."
  validation {
    condition     = startswith(var.tier, "db-custom-")
    error_message = "Use a db-custom tier."
  }
}

variable "availability_type" {
  type        = string
  description = "ZONAL or REGIONAL."
  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "ZONAL or REGIONAL."
  }
}

variable "retained_backups" {
  type        = number
  description = "Number of automated backups kept."
  validation {
    condition     = var.retained_backups >= 7 && var.retained_backups <= 365
    error_message = "Between 7 and 365."
  }
}

variable "app_password" {
  type        = string
  description = "Password of the ledger_app user."
  sensitive   = true
}
