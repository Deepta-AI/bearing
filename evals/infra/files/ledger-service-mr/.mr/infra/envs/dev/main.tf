terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  backend "gcs" {
    prefix = "ledger/dev"
  }
}

variable "project_id" {
  type        = string
  description = "Google Cloud project of this environment."
}

variable "network_id" {
  type        = string
  description = "VPC id, an output of the network repository."
}

provider "google" {
  project = var.project_id
  region  = "asia-south1"
}

module "ledger_api_sa" {
  source        = "../../modules/service-account"
  project_id    = var.project_id
  account_id    = "ledger-api"
  project_roles = ["roles/cloudsql.client", "roles/logging.logWriter"]
}

module "ledger_worker_sa" {
  source     = "../../modules/service-account"
  project_id = var.project_id
  account_id = "ledger-worker"
  project_roles = [
    "roles/cloudsql.client",
    "roles/secretmanager.secretAccessor",
    "roles/logging.logWriter",
  ]
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "ledger-db-password"
  replication {
    user_managed {
      replicas {
        location = "asia-south1"
      }
    }
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}

resource "google_secret_manager_secret_iam_member" "api_reads_db_password" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = module.ledger_api_sa.member
}

# Holds the payout partner's API key. The value is added by hand by the
# payments lead, never by Terraform. Only ledger-api's payout job reads it.
resource "google_secret_manager_secret" "payout_api_key" {
  secret_id = "payout-partner-api-key"
  replication {
    user_managed {
      replicas {
        location = "asia-south1"
      }
    }
  }
}

resource "google_secret_manager_secret_iam_member" "api_reads_payout_key" {
  secret_id = google_secret_manager_secret.payout_api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = module.ledger_api_sa.member
}

module "database" {
  source            = "../../modules/database"
  env               = "dev"
  region            = "asia-south1"
  network_id        = var.network_id
  tier              = "db-custom-1-3840"
  availability_type = "ZONAL"
  retained_backups  = 7
  app_password      = random_password.db.result
}
