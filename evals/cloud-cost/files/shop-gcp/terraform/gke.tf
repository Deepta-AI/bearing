locals {
  pools = {
    "shop-prod"    = { location = "asia-south1", machine = "n2-standard-8", nodes = 6 }
    "shop-staging" = { location = "asia-south1-a", machine = "n2-standard-8", nodes = 3 }
    "shop-dev"     = { location = "asia-south1-a", machine = "n2-standard-4", nodes = 2 }
  }
}

resource "google_container_cluster" "shop" {
  for_each                 = local.pools
  project                  = each.key
  name                     = each.key
  location                 = each.value.location
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "main" {
  for_each   = local.pools
  project    = each.key
  cluster    = google_container_cluster.shop[each.key].name
  location   = each.value.location
  node_count = each.value.nodes
  node_config {
    machine_type = each.value.machine
    labels       = { env = trimprefix(each.key, "shop-") }
  }
}
