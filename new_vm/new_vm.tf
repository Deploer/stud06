terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
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
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

provider "yandex" {
  service_account_key_file = "/root/key.json"
  cloud_id  = "b1gh268nmke9btt81pou"
  folder_id = "b1gslld5kk9vkm5u7prh"
  zone = "ru-central1-e"
}

resource "yandex_compute_image" "ubuntu_2004" {
  source_family = "ubuntu-2404-lts"
}

# Диск ВМ1 — зона e
resource "yandex_compute_disk" "boot-disk-vm1" {
  name     = "boot-disk-1"
  type     = "network-hdd"
  zone     = "ru-central1-e"
  size     = "10"
  image_id = yandex_compute_image.ubuntu_2004.id
}


# ВМ1
resource "yandex_compute_instance" "vm-1" {
  name        = "vm1"
  platform_id = "standard-v3"
  zone        = "ru-central1-e"

  resources {
    cores  = 2
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

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

# Подсеть для вм1
resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-e"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}


output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.ip_address
}


output "external_ip_address_vm_1" {
  value = yandex_compute_instance.vm-1.network_interface.0.nat_ip_address
}


output "subnet-1" {
  value = yandex_vpc_subnet.subnet-1.id
}

