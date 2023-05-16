provider "yandex" {
  #  version                  = 0.35
  token     = var.token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}


data "yandex_compute_image" "ubuntu-image" {
  family = "ubuntu-1804-lts"
}

resource "yandex_compute_instance" "k8s" {
  name  = "k8s-${count.index}"
  count = var.instance_count

  resources {
    cores  = 4
    memory = 4
  }

  boot_disk {
    initialize_params {
      #image_id = var.image_id
      image_id = data.yandex_compute_image.ubuntu-image.image_id
      size     = 40
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = var.subnet_id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }
}

locals {
  names     = yandex_compute_instance.k8s.*.name
  nat_ips   = yandex_compute_instance.k8s.*.network_interface.0.nat_ip_address
  local_ips = yandex_compute_instance.k8s.*.network_interface.0.ip_address
}

# Inventory for ansible and run playbook
resource "local_file" "inventory" {
  content = templatefile("inventory.tpl",
    {
      #k8s_hosts = yandex_compute_instance.k8s.*.network_interface.0.nat_ip_address
      names       = local.names,
      ext_addrs   = local.nat_ips,
      local_addrs = local.local_ips,
    }
  )
  filename = "../kubespray/inventory/terraform/inventory.ini"

  provisioner "local-exec" {
    command = "sleep 180"
  }

  provisioner "local-exec" {
    environment = {
      SSH_USERNAME    = var.ssh_username
      SSH_PRIVATE_KEY = var.private_key_path
    }
    command     = "ansible-playbook -i inventory/terraform/inventory.ini --become --become-user=root --user=$SSH_USERNAME --key-file=$SSH_PRIVATE_KEY cluster.yml"
    working_dir = "../kubespray"
  }
}
