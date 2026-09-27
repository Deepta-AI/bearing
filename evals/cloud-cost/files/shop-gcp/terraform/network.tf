resource "google_compute_network" "prod" {
  project                 = "shop-prod"
  name                    = "shop-prod"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "mumbai" {
  project       = "shop-prod"
  name          = "mumbai"
  region        = "asia-south1"
  network       = google_compute_network.prod.id
  ip_cidr_range = "10.50.0.0/16"
}

resource "google_compute_subnetwork" "delhi" {
  project       = "shop-prod"
  name          = "delhi"
  region        = "asia-south2"
  network       = google_compute_network.prod.id
  ip_cidr_range = "10.60.0.0/16"
}

# Kept after the move to GKE; the old ingress VM is gone.
resource "google_compute_address" "legacy_ingress" {
  project = "shop-prod"
  name    = "legacy-ingress-ip"
  region  = "asia-south1"
}
