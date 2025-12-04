
resource "google_compute_network" "vpc" {
  name = "myvpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "sub1" {
  name          = "subnet-1"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_subnetwork" "sub2" {
  name          = "subnet-2"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_firewall" "firewall" {
  name    = "web-firewall"
  network = google_compute_network.vpc.id
 
  allow {
    protocol = "tcp"
    ports    = ["80", "22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_storage_bucket" "bucket" {
  name          = "terraform-test-1204"
  location      = "US"
}  

resource "google_compute_instance" "vm1" {
  name         = "web-server1"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
   }
  }

  network_interface {
    network = google_compute_subnetwork.sub1.id
    access_config {}
  }

     metadata_startup_script = file("userdata.sh")
}

resource "google_compute_instance" "vm2" {
  name         = "web-server2"
  machine_type = "e2-micro"
  zone         = "us-central1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
   }
  }

  network_interface {
    network = google_compute_subnetwork.sub2.id
    access_config {}
  }

     metadata_startup_script = file("userdata1.sh")
}

resource "google_compute_instance_group" "web_group" {
  name        = "web_ig"
  zone        = var.zone
  instances = [
    google_compute_instance.vm1.id,
    google_compute_instance.vm2.id
  ]

  named_port {
    name = "http"
    port = "80"
  }

  
}

resource "google_compute_health_check" "hc" {
  name        = "tcp-health-check"
  description = "Health check via tcp"

  timeout_sec         = 5
  check_interval_sec  = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port = 80
  }
}

resource "google_compute_backend_service" "backend" {
  name                  = "web-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  health_checks = google_compute_health_check.hc.id

  backend {
    group = google_compute_instance_group.web_group.self_link
  }
}

resource "google_compute_url_map" "urlmap" {
  name        = "web_urlmap"
  default_service = google_compute_backend_service.backend.id
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name                        = "http_proxy"
  url_map                     = google_compute_url_map.urlmap.id
}

resource "google_compute_forwarding_rule" "rule" {
  name                  = "http-forwarding-rule"
  target                = google_compute_target_http_proxy.http_proxy.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL"
}

output "load_balancer_ip" {
  value = google_compute_forwarding_rule.rule.ip_address
}
 