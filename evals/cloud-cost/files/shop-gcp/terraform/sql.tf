resource "google_sql_database_instance" "primary" {
  project          = "shop-prod"
  name             = "pg-primary"
  region           = "asia-south1"
  database_version = "POSTGRES_16"
  settings {
    tier              = "db-custom-8-32768"
    availability_type = "REGIONAL"
    user_labels       = { env = "prod", app = "postgres" }
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.prod.id
    }
  }
}

# Private IP 10.60.0.5 in the delhi subnet.
resource "google_sql_database_instance" "replica_dr" {
  project              = "shop-prod"
  name                 = "pg-replica-dr"
  region               = "asia-south2"
  database_version     = "POSTGRES_16"
  master_instance_name = google_sql_database_instance.primary.name
  settings {
    tier              = "db-custom-8-32768"
    availability_type = "ZONAL"
    user_labels       = { env = "prod", app = "postgres-dr" }
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.prod.id
    }
  }
}
