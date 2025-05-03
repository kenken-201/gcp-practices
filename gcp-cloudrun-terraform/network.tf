resource "google_compute_network" "vpc_network" {
  name = "main-network"
}

# CloudRun -- (VPC Access Connector) --> VPC Network という経路を作成

# CloudRunからVPC内にアクセスするために必要なVPC Access Connectorを作成
# VPC Access Connectorは、VPC Network内の10.20.0.0/28というIPアドレス範囲をConnectorに割り当てる
resource "google_vpc_access_connector" "connector" {
  name          = "vpc-con"
  ip_cidr_range = "10.20.0.0/28"
  network       = google_compute_network.vpc_network.id
}

# VPC Network -- (Private Service Access) --> CloudSQL という経路を作成

# 10.10.0.0/16のIPアドレス範囲をPrivate Service Accessに割り当てる
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = "10.10.0.0"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
}

resource "google_service_networking_connection" "default" {
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}
