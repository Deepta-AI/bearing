# dev environment root. Wires modules and passes values; declares no
# resource of its own without a comment saying why.

provider "google" {
  project = var.project
  region  = var.region
}

locals {
  env = "dev"
}

module "network" {
  source = "../../modules/network"

  name    = "__REPO_SLUG__-${local.env}"
  project = var.project
  region  = var.region

  subnets = {
    "__REPO_SLUG__-${local.env}-apps" = {
      region = var.region
      cidr   = var.apps_cidr
      secondary_ranges = {
        pods     = var.pods_cidr
        services = var.services_cidr
      }
    }
  }

  enable_nat        = true
  flow_log_sampling = 0.1
}

module "app_service_account" {
  source = "../../modules/service-account"

  account_id   = "__REPO_SLUG__-${local.env}-app"
  display_name = "__REPO_NAME__ app (${local.env})"
  project      = var.project
  roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ]
  workload_identity_user = "serviceAccount:${var.project}.svc.id.goog[__REPO_SLUG__-${local.env}/__REPO_SLUG__]"
}
