terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  # version                  = 0.35
  #service_account_key_file = var.service_account_key_file
  token     = var.token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

resource "yandex_kubernetes_cluster" "k8s-cluster" {
  name       = var.cluster_name
  network_id = var.network_id

  master {
    version = var.k8s_version
    zonal {
      zone      = var.zone
      subnet_id = var.subnet_id
    }
    public_ip = true
  }

  service_account_id      = var.service_account_id
  node_service_account_id = var.service_account_id

  release_channel         = "RAPID"
  network_policy_provider = "CALICO"
}

resource "yandex_kubernetes_node_group" "k8s-nodes" {
  cluster_id = yandex_kubernetes_cluster.k8s-cluster.id
  version    = var.k8s_version
  name       = "k8s-nodes"

  instance_template {

    network_interface {
      nat        = true
      subnet_ids = [var.subnet_id]
    }
    #     nat = true

    resources {
      cores  = var.cores
      memory = var.memory
    }

    boot_disk {
      type = "network-ssd-nonreplicated"
      size = var.disk
    }

    container_runtime {
      type = "containerd"
    }

    metadata = {
      ssh-keys = "appuser:${file(var.public_key_path)}"
    }
  }

  scale_policy {
    fixed_scale {
      size = var.count_of_workers
    }
  }

  provisioner "local-exec" {
    command = "yc managed-kubernetes cluster get-credentials $CLUSTER_NAME --external --force --folder-id $FOLDER_ID"
    environment = {
      CLUSTER_NAME = var.cluster_name
      FOLDER_ID    = var.folder_id
    }
  }
}
