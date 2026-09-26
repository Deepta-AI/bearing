# Network: one VPC, its subnets, and Cloud NAT so private nodes have egress
# without public addresses. Google Cloud is the default; tech-decision key `cloud` chooses.
#
# AWS equivalent: aws_vpc (auto_create_subnetworks has no analogue, subnets
# are always explicit), aws_subnet per availability zone, aws_flow_log for
# the log_config block, aws_nat_gateway plus aws_eip and a route table for
# the router and NAT pair. Secondary ranges have no analogue: EKS pods take
# addresses from the subnet itself.

resource "google_compute_network" "this" {
  name                    = var.name
  project                 = var.project
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "Managed by Terraform (__REPO_NAME__)"
}

resource "google_compute_subnetwork" "this" {
  for_each = var.subnets

  name                     = each.key
  project                  = var.project
  region                   = each.value.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = each.value.cidr
  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ranges
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }

  # Flow logs on every subnet; the sampling rate is the only knob per env.
  log_config {
    aggregation_interval = "INTERVAL_5_MIN"
    flow_sampling        = var.flow_log_sampling
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router" "this" {
  count = var.enable_nat ? 1 : 0

  name    = "${var.name}-router"
  project = var.project
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  count = var.enable_nat ? 1 : 0

  name                               = "${var.name}-nat"
  project                            = var.project
  region                             = var.region
  router                             = google_compute_router.this[0].name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
