#не рабочий вариант

terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"

  backend "s3" {
      endpoints = {
        s3 = "https://storage.yandexcloud.net"
      }
      bucket = "terraform"
      region = "ru-central1"
      key    = "my-terraform/terraform.tfstate"

      skip_region_validation      = true
      skip_credentials_validation = true
      skip_requesting_account_id  = true # Необходимая опция Terraform для версии 1.6.1 и старше.
      skip_s3_checksum            = true # Необходимая опция при описании бэкенда для Terraform версии 1.6.3 и старше.

    }
}

provider "yandex" {
  service_account_key_file = "/root/key.json"   # путь к вашему key.json
  cloud_id  = "b1gh268nmke9btt81pou"
  folder_id = "b1gslld5kk9vkm5u7prh"
  zone = "ru-central1-a"
}



resource "yandex_compute_image" "ubuntu_2004" {
  source_family = "ubuntu-2004-lts"
}

resource "yandex_compute_disk" "boot-disk-vm1" {
  name     = "boot-disk-1"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = "10"
  image_id = yandex_compute_image.ubuntu_2004.id
}

resource "yandex_compute_disk" "boot-disk-vm2" {
  name     = "boot-disk-2"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = "10"
  image_id = yandex_compute_image.ubuntu_2004.id
}

resource "yandex_compute_instance" "vm-1" {
  name = "terraform1"
  platform_id = "standard-v1"
  resources {
    cores  = 1
    memory = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-vm1.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
        ssh-keys = "ubuntu:${file("/root/.ssh/id_ed25519.pub")}"
  }
}

resource "yandex_compute_instance" "vm-2" {
  name = "terraform2"
  platform_id = "standard-v1"
  resources {
    cores  = 1
    memory = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-vm2.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("/root/.ssh/id_ed25519.pub")}"
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.ip_address
}

output "internal_ip_address_vm_2" {
  value = yandex_compute_instance.vm-2.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}

output "external_ip_address_vm_2" {
  value = yandex_compute_instance.vm-2.network_interface.0.nat_ip_address
}

output "subnet-1" {
  value = yandex_vpc_subnet.subnet-1.id
}