variable "project" {
  description = "Google Cloud project id for prod."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project))
    error_message = "project must be a valid Google Cloud project id (6 to 30 lowercase characters)."
  }
}

variable "region" {
  description = "Default region for regional resources."
  type        = string
  default     = "asia-south1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "region must look like asia-south1."
  }
}

variable "apps_cidr" {
  description = "Primary CIDR of the applications subnet. Never overlaps another environment."
  type        = string
  default     = "10.30.0.0/20"

  validation {
    condition     = can(cidrhost(var.apps_cidr, 0))
    error_message = "apps_cidr must be a valid CIDR block."
  }
}

variable "pods_cidr" {
  description = "Secondary range for Kubernetes pods."
  type        = string
  default     = "10.31.0.0/16"

  validation {
    condition     = can(cidrhost(var.pods_cidr, 0))
    error_message = "pods_cidr must be a valid CIDR block."
  }
}

variable "services_cidr" {
  description = "Secondary range for Kubernetes services."
  type        = string
  default     = "10.32.0.0/20"

  validation {
    condition     = can(cidrhost(var.services_cidr, 0))
    error_message = "services_cidr must be a valid CIDR block."
  }
}
