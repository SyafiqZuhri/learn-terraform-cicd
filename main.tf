# =========================================================
# 1. PROVIDER & PENGATURAN DASAR
# =========================================================
terraform {
  backend "gcs" {
    bucket = "my-terraform-state-bucket"
    prefix = "terraform/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.45.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38.0"
    }
  }
}

provider "google" {
  project = "tab-dev-playground" # Sesuaikan jika Project ID kamu berbeda
  region  = "asia-southeast2"
  zone    = "asia-southeast2-a"
}

# =========================================================
# 2. INFRASTRUKTUR GKE (KUBERNETES CLUSTER)
# =========================================================
resource "google_container_cluster" "primary" {
  name               = "cluster-zuhri"
  location           = "asia-southeast2-a"
  initial_node_count = 1
  deletion_protection = false

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

# =========================================================
# 3. KONEKSI TERRAFORM KE DALAM CLUSTER KUBERNETES
# =========================================================
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# =========================================================
# 4. APLIKASI KUBERNETES (DASHBOARD NGINX & LOAD BALANCER)
# =========================================================

# --- A. ConfigMap (Menyimpan File HTML Dashboard) ---
resource "kubernetes_config_map" "dashboard_html" {
  metadata {
    name = "dashboard-html-config"
  }

  data = {
    "index.html" = <<EOF
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DevOps Dashboard</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #e9ecef; margin: 0; padding: 20px; }
        .header { background-color: #343a40; color: white; padding: 20px; text-align: center; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .container { display: flex; justify-content: center; gap: 20px; flex-wrap: wrap; }
        .card { background: white; padding: 25px; border-radius: 10px; box-shadow: 0 4px 8px rgba(0,0,0,0.05); width: 250px; text-align: center; border-top: 4px solid #007bff; }
        h3 { color: #495057; margin-top: 0; }
        .status-up { color: #28a745; font-weight: bold; font-size: 1.2em; }
        .footer { margin-top: 40px; text-align: center; color: #6c757d; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚀 Dashboard Infrastruktur GKE</h1>
        <p>Di-deploy secara otomatis melalui Jenkins Pipeline & Terraform</p>
    </div>
    <div class="container">
        <div class="card">
            <h3>Status Web Server</h3>
            <p class="status-up">🟢 ONLINE & SEHAT</p>
        </div>
        <div class="card">
            <h3>Load Balancer</h3>
            <p>Aktif (Port 80)</p>
        </div>
        <div class="card">
            <h3>Total Replika Pod</h3>
            <p style="font-size: 1.2em; font-weight: bold; color: #17a2b8;">2 Nodes</p>
        </div>
    </div>
    <div class="footer">
        <p>Dikelola dengan ❤️ menggunakan CI/CD Automation</p>
    </div>
</body>
</html>
EOF
  }
}

# --- B. Deployment (Menjalankan Web Server Nginx) ---
resource "kubernetes_deployment" "app_web_zuhri" {
  metadata {
    name = "web-deployment-zuhri"
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "nginx-web"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx-web"
        }
      }
      spec {
        volume {
          name = "html-volume"
          config_map {
            name = kubernetes_config_map.dashboard_html.metadata[0].name
          }
        }
        container {
          image = "nginx:latest"
          name  = "nginx-container"
          port {
            container_port = 80
          }
          volume_mount {
            name       = "html-volume"
            mount_path = "/usr/share/nginx/html"
          }
        }
      }
    }
  }
}

# --- C. Service (Membuka Akses Internet via IP Publik) ---
resource "kubernetes_service" "service_web_zuhri" {
  metadata {
    name = "web-service-zuhri"
  }
  spec {
    selector = {
      app = "nginx-web"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}
