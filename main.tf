terraform {
  required_providers {
    google     = { source = "hashicorp/google", version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.0" }
  }
  backend "gcs" {
    bucket = "bucket-state-terraform-zuhri-99"
    prefix = "terraform/state-gke"
  }
}

provider "google" {
  project = "tab-dev-playground"
  region  = "asia-southeast2"
}

# 1. Membuat Cluster GKE
resource "google_container_cluster" "primary" {
  name               = "cluster-zuhri"
  location           = "asia-southeast2-a"
  initial_node_count = 1

  node_config {
    machine_type = "e2-medium"
  }
}

# 2. Konfigurasi Provider Kubernetes agar menunggu GKE selesai
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# 3. Deployment Aplikasi
resource "kubernetes_deployment" "app_web_zuhri" {
  depends_on = [google_container_cluster.primary] # KUNCI UTAMA: Tunggu cluster jadi dulu
  metadata {
    name = "web-deployment-zuhri"
  }
  spec {
    replicas = 2
    selector { match_labels = { app = "web" } }
    template {
      metadata { labels = { app = "web" } }
      spec {
        container {
          name  = "nginx-container"
          image = "nginx:alpine"
          port { container_port = 80 }
        }
      }
    }
  }
}

# 4. Service Aplikasi
resource "kubernetes_service" "service_web_zuhri" {
  depends_on = [google_container_cluster.primary] # KUNCI UTAMA: Tunggu cluster jadi dulu
  metadata {
    name = "web-service-zuhri"
  }
  spec {
    selector = { app = "web" }
    port { port = 80 }
    type = "LoadBalancer" # GKE otomatis membuat Load Balancer publik
  }
}