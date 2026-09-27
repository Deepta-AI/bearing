resource "google_sql_database_instance" "main" {
  name             = "ledger-db"
  database_version = "POSTGRES_16"
  region           = var.region

  settings {
    tier              = var.tier
    availability_type = var.availability_type

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
    }

    backup_configuration {
      enabled                        = true
      location                       = var.region
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = var.retained_backups
      }
    }
  }
}

resource "google_sql_database" "ledger" {
  name     = "ledger"
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "app" {
  name     = "ledger_app"
  instance = google_sql_database_instance.main.name
  password = var.app_password
}
