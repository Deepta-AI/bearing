variable "name" {
  description = "VPC name, also the prefix for the router and NAT. Lowercase, hyphenated, 1 to 50 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,48}[a-z0-9]$", var.name))
    error_message = "name must match ^[a-z][a-z0-9-]{0,48}[a-z0-9]$."
  }
}

variable "project" {
  description = "Google Cloud project id that owns the network."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project))
    error_message = "project must be a valid Google Cloud project id (6 to 30 lowercase characters)."
  }
}

variable "region" {
  description = "Region for the router and NAT (subnets carry their own region)."
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "region must look like asia-south1."
  }
}

variable "subnets" {
  description = "Subnets keyed by name: region, primary CIDR and optional secondary ranges (name to CIDR) for pods and services."
  type = map(object({
    region           = string
    cidr             = string
    secondary_ranges = optional(map(string), {})
  }))

  validation {
    condition     = length(var.subnets) > 0
    error_message = "subnets must declare at least one subnet."
  }

  validation {
    condition = alltrue([
      for s in values(var.subnets) : can(cidrhost(s.cidr, 0)) && alltrue([for r in values(s.secondary_ranges) : can(cidrhost(r, 0))])
    ])
    error_message = "every cidr and secondary range must be a valid CIDR block."
  }
}

variable "flow_log_sampling" {
  description = "Fraction of flows sampled into VPC flow logs, 0 to 1. Dev samples lightly, prod samples more."
  type        = number
  default     = 0.5

  validation {
    condition     = var.flow_log_sampling >= 0 && var.flow_log_sampling <= 1
    error_message = "flow_log_sampling must be between 0 and 1."
  }
}

variable "enable_nat" {
  description = "Create a Cloud Router and NAT so private instances reach the internet."
  type        = bool
  default     = true
}
