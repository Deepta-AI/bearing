# Month-end invoicing, see docs/runbooks/month-end.md.
resource "google_compute_instance" "invoicer" {
  project      = "shop-prod"
  name         = "month-end-invoicer"
  zone         = "asia-south1-a"
  machine_type = "e2-standard-16"
  boot_disk {
    initialize_params { image = "debian-cloud/debian-12" }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.mumbai.id
  }
}
