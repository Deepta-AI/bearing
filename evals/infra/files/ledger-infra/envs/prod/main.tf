terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
  # The bucket arrives at init: -backend-config="bucket=$TF_BACKEND_BUCKET".
  backend "gcs" {
    prefix = "ledger/prod"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  default_labels = {
    env        = "prod"
    repo       = "ledger-infra"
    managed_by = "terraform"
  }
}

locals {
  env           = "prod"
  nodes_cidr    = "10.30.0.0/20"
  services_cidr = "10.30.16.0/20"
  pods_cidr     = "10.30.64.0/18"
  # Second pod range for the pool-b node pool (INFRA-212, August 2026).
  extra_pods_cidrs = {
    "pods-b" = "10.30.32.0/19"
  }
}

module "network" {
  source           = "../../modules/network"
  name             = "ledger-${local.env}"
  region           = var.region
  nodes_cidr       = local.nodes_cidr
  pods_cidr        = local.pods_cidr
  services_cidr    = local.services_cidr
  extra_pods_cidrs = local.extra_pods_cidrs
}

module "ledger_api_sa" {
  source     = "../../modules/service-account"
  project_id = var.project_id
  account_id = "ledger-api"
  project_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ]
}
