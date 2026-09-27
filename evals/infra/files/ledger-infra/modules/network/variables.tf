variable "name" {
  type        = string
  description = "Prefix for network resource names, for example ledger-dev."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.name))
    error_message = "name must be lowercase letters, digits and hyphens."
  }
}

variable "region" {
  type        = string
  description = "Region of the subnet."
  validation {
    condition     = var.region == "asia-south1"
    error_message = "ADR-0001: asia-south1 only."
  }
}

variable "nodes_cidr" {
  type        = string
  description = "Primary range of the GKE subnet."
  validation {
    condition     = can(cidrhost(var.nodes_cidr, 0))
    error_message = "nodes_cidr must be a CIDR."
  }
}

variable "pods_cidr" {
  type        = string
  description = "Secondary range for GKE pods."
  validation {
    condition     = can(cidrhost(var.pods_cidr, 0))
    error_message = "pods_cidr must be a CIDR."
  }
}

variable "services_cidr" {
  type        = string
  description = "Secondary range for GKE services."
  validation {
    condition     = can(cidrhost(var.services_cidr, 0))
    error_message = "services_cidr must be a CIDR."
  }
}

variable "extra_pods_cidrs" {
  type        = map(string)
  description = "Additional pod ranges (GKE discontiguous multi-pod CIDR), keyed by secondary range name."
  default     = {}
  validation {
    condition     = alltrue([for c in values(var.extra_pods_cidrs) : can(cidrhost(c, 0))])
    error_message = "Every extra pod range must be a CIDR."
  }
}
