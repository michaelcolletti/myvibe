# main.tf
# This file defines the core infrastructure resources for the MyVibe application.

# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# -----------------------------------------------------------------------------
# 1. Networking: VPC Network, Subnets, and Firewall Rules
# -----------------------------------------------------------------------------

# Custom VPC Network for isolation
resource "google_compute_network" "myvibe_vpc" {
  name                    = "myvibe-vpc"
  auto_create_subnetworks = false # We'll create custom subnets for better control
  routing_mode            = "REGIONAL" # Regional routing mode
  description             = "VPC network for MyVibe three-tier application."
}

# Subnet for the Web Tier
resource "google_compute_subnetwork" "web_subnet" {
  name          = "myvibe-web-subnet"
  ip_cidr_range = "10.0.1.0/24" # Example CIDR range
  region        = var.region
  network       = google_compute_network.myvibe_vpc.id
  description   = "Subnet for the MyVibe web tier."
}

# Subnet for the Application Tier
resource "google_compute_subnetwork" "app_subnet" {
  name          = "myvibe-app-subnet"
  ip_cidr_range = "10.0.2.0/24" # Example CIDR range
  region        = var.region
  network       = google_compute_network.myvibe_vpc.id
  description   = "Subnet for the MyVibe application tier."
}

# Subnet for the Database Tier
resource "google_compute_subnetwork" "db_subnet" {
  name          = "myvibe-db-subnet"
  ip_cidr_range = "10.0.3.0/24" # Example CIDR range
  region        = var.region
  network       = google_compute_network.myvibe_vpc.id
  description   = "Subnet for the MyVibe database tier."
}

# Firewall rule to allow SSH access to all instances
# IMPORTANT: In production, restrict source_ranges to specific IPs or use IAP.
resource "google_compute_firewall" "allow_ssh" {
  name    = "myvibe-allow-ssh"
  network = google_compute_network.myvibe_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["22"] # Standard SSH port
  }
  source_ranges = ["0.0.0.0/0"] # Allows SSH from any IP (for demonstration)
  target_tags   = ["myvibe-web", "myvibe-app", "myvibe-db"] # Apply to all tier VMs
  description   = "Allows SSH access to MyVibe instances."
}

# Firewall rule to allow HTTP and HTTPS traffic to the web tier
resource "google_compute_firewall" "allow_http_https" {
  name    = "myvibe-allow-http-https"
  network = google_compute_network.myvibe_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["80", "443"] # Standard HTTP and HTTPS ports
  }
  source_ranges = ["0.0.0.0/0"] # Allows traffic from any IP
  target_tags   = ["myvibe-web"] # Apply only to web tier VMs
  description   = "Allows HTTP/HTTPS traffic to the MyVibe web tier."
}

# Firewall rule to allow communication from the web tier to the app tier
resource "google_compute_firewall" "allow_web_to_app" {
  name    = "myvibe-allow-web-to-app"
  network = google_compute_network.myvibe_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["8080"] # Example port for application server
  }
  source_tags = ["myvibe-web"] # Traffic originates from web tier VMs
  target_tags = ["myvibe-app"] # Traffic destined for app tier VMs
  description = "Allows web tier to communicate with app tier."
}

# Firewall rule to allow communication from the app tier to the database tier
resource "google_compute_firewall" "allow_app_to_db" {
  name    = "myvibe-allow-app-to-db"
  network = google_compute_network.myvibe_vpc.name
  allow {
    protocol = "tcp"
    ports    = ["3306", "5432"] # Common ports for MySQL (3306) and PostgreSQL (5432)
  }
  source_tags = ["myvibe-app"] # Traffic originates from app tier VMs
  target_tags = ["myvibe-db"] # Traffic destined for db tier VMs
  description = "allow app tier to communicate with database tier."
}

# -----------------------------------------------------------------------------
# 2. Service Accounts: For Least Privilege Access
# -----------------------------------------------------------------------------

# Service Account for the Web Tier VM
resource "google_service_account" "web_sa" {
  account_id   = "myvibe-web-sa"
  display_name = "Service Account for MyVibe Web Tier"
  project      = var.project_id
}

# Service Account for the App Tier VM
resource "google_service_account" "app_sa" {
  account_id   = "myvibe-app-sa"
  display_name = "Service Account for MyVibe App Tier"
  project      = var.project_id
}

# Service Account for the DB Tier VM
resource "google_service_account" "db_sa" {
  account_id   = "myvibe-db-sa"
  display_name = "Service Account for MyVibe DB Tier"
  project      = var.project_id
}

# IAM Bindings for Service Accounts (Least Privilege)
# Grant logging and monitoring write permissions to all service accounts.
# Add more specific roles if your application needs to interact with other GCP services.

resource "google_project_iam_member" "web_sa_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.web_sa.email}"
}

resource "google_project_iam_member" "web_sa_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.web_sa.email}"
}

resource "google_project_iam_member" "app_sa_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_project_iam_member" "app_sa_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_project_iam_member" "db_sa_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.db_sa.email}"
}

resource "google_project_iam_member" "db_sa_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.db_sa.email}"
}

# -----------------------------------------------------------------------------
# 3. Compute Engine Instances (VMs) for Each Tier
# -----------------------------------------------------------------------------

# Web Tier Instance
resource "google_compute_instance" "web_instance" {
  name         = "myvibe-web-instance"
  machine_type = "e2-micro" # Free-tier eligible machine type (only one is free)
  zone         = var.zone
  tags         = ["myvibe-web"] # Used for firewall rules

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11" # Using a stable Debian image
      size  = 10 # 10GB disk (exceeds free tier 5GB limit)
    }
  }

  network_interface {
    network    = google_compute_network.myvibe_vpc.id
    subnetwork = google_compute_subnetwork.web_subnet.id
    access_config { # Assign a public IP for external access
      // Ephemeral public IP address
    }
  }

  service_account {
    email  = google_service_account.web_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"] # Broad scope for basic operations, IAM roles define actual permissions
  }

  # Startup script to install Nginx and create a simple index page
  metadata_startup_script = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    echo "<h1>Hello from MyVibe Web Tier!</h1>" | sudo tee /var/www/html/index.nginx-debian.html
  EOF
}

# Application Tier Instance
resource "google_compute_instance" "app_instance" {
  name         = "myvibe-app-instance"
  machine_type = "e2-micro" # Free-tier eligible machine type
  zone         = var.zone
  tags         = ["myvibe-app"] # Used for firewall rules

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10 # 10GB disk
    }
  }

  network_interface {
    network    = google_compute_network.myvibe_vpc.id
    subnetwork = google_compute_subnetwork.app_subnet.id
    # No access_config block means no public IP (private IP only)
  }

  service_account {
    email  = google_service_account.app_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # Placeholder startup script for the app tier
  metadata_startup_script = <<-EOF
    #!/bin/bash
    sudo apt-get update
    # Example: sudo apt-get install -y default-jdk # Install Java for a Java app
    echo "<h1>Hello from MyVibe App Tier! (Placeholder)</h1>" | sudo tee /tmp/app_status.html
  EOF
}

# Database Tier Instance (Self-managed)
resource "google_compute_instance" "db_instance" {
  name         = "myvibe-db-instance"
  machine_type = "e2-micro" # Free-tier eligible machine type
  zone         = var.zone
  tags         = ["myvibe-db"] # Used for firewall rules

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10 # 10GB disk
    }
  }

  network_interface {
    network    = google_compute_network.myvibe_vpc.id
    subnetwork = google_compute_subnetwork.db_subnet.id
    # No access_config block means no public IP (private IP only)
  }

  service_account {
    email  = google_service_account.db_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # Placeholder startup script to install MySQL server
  metadata_startup_script = <<-EOF
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y mysql-server # Example: Install MySQL
    sudo systemctl start mysql
    sudo systemctl enable mysql
    echo "<h1>Hello from MyVibe DB Tier! (Placeholder)</h1>" | sudo tee /tmp/db_status.html
  EOF
}

