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
  source_family = "ubuntu-2004-lts"
}

# Диск ВМ1 — зона e
resource "yandex_compute_disk" "boot-disk-vm1" {
  name     = "boot-disk-1"
  type     = "network-hdd"
  zone     = "ru-central1-e"
  size     = "10"
  image_id = yandex_compute_image.ubuntu_2004.id
}

# Диск ВМ2 — зона d
resource "yandex_compute_disk" "boot-disk-vm2" {
  name     = "boot-disk-2"
  type     = "network-hdd"
  zone     = "ru-central1-d"
  size     = "10"
  image_id = yandex_compute_image.ubuntu_2004.id
}

# ВМ1
resource "yandex_compute_instance" "vm-1" {
  name        = "terraform1"
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

# ВМ2
resource "yandex_compute_instance" "vm-2" {
  name        = "terraform2"
  platform_id = "standard-v3"
  zone        = "ru-central1-d"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk-vm2.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-2.id
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

# Подсеть для вм2
resource "yandex_vpc_subnet" "subnet-2" {
  name           = "subnet2"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.20.0/24"]
}

variable "dockerhub_username" {
  type = string
  default = "deploer"
}

variable "dockerhub_repository" {
  type    = string
  default = "chess"
}

variable "dockerhub_token" {
  type      = string
  sensitive = true
  
}

variable "dockerhub_image_tag" {
  type    = string
  default = "latest"
}

locals {
  docker_image = "${var.dockerhub_username}/${var.dockerhub_repository}:${var.dockerhub_image_tag}"
  source_hash = sha256(join("", [
    filesha256("${path.module}/Dockerfile"),
    filesha256("${path.module}/pom.xml"),
    join("", [for file in sort(fileset("${path.module}/src", "**")) : filesha256("${path.module}/src/${file}")])
  ]))
}

resource "null_resource" "build_and_push_image" {
  triggers = {
    source_hash = local.source_hash
    builder_id  = yandex_compute_instance.vm-1.id
    image       = local.docker_image
  }

  connection {
    type        = "ssh"
    host        = yandex_compute_instance.vm-1.network_interface[0].nat_ip_address
    user        = "ubuntu"
    private_key = file("/root/.ssh/id_ed25519")
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y docker.io",
      "sudo systemctl enable --now docker",
      "mkdir -p /home/ubuntu/app/src"
    ]
  }

  provisioner "file" {
    source      = "${path.module}/Dockerfile"
    destination = "/home/ubuntu/app/Dockerfile"
  }

  provisioner "file" {
    source      = "${path.module}/pom.xml"
    destination = "/home/ubuntu/app/pom.xml"
  }

  provisioner "file" {
    source      = "${path.module}/src"
    destination = "/home/ubuntu/app/src"
  }

  provisioner "file" {
    content     = var.dockerhub_token
    destination = "/home/ubuntu/.dockerhub_token"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ubuntu/.dockerhub_token",
      "sudo docker login --username '${var.dockerhub_username}' --password-stdin < /home/ubuntu/.dockerhub_token || { rm -f /home/ubuntu/.dockerhub_token; exit 1; }",
      "rm -f /home/ubuntu/.dockerhub_token",
      "sudo docker build --pull --tag '${local.docker_image}' /home/ubuntu/app",
      "sudo docker push '${local.docker_image}'",
      "sudo docker logout"
    ]
  }
}

resource "null_resource" "run_container" {
  depends_on = [null_resource.build_and_push_image]

  triggers = {
    image  = local.docker_image
    build  = null_resource.build_and_push_image.id
    vm_id  = yandex_compute_instance.vm-2.id
  }

  connection {
    type        = "ssh"
    host        = yandex_compute_instance.vm-2.network_interface[0].nat_ip_address
    user        = "ubuntu"
    private_key = file("/root/.ssh/id_ed25519")
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y docker.io",
      "sudo systemctl enable --now docker"
    ]
  }

  provisioner "file" {
    content     = var.dockerhub_token
    destination = "/home/ubuntu/.dockerhub_token"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ubuntu/.dockerhub_token",
      "sudo docker login --username '${var.dockerhub_username}' --password-stdin < /home/ubuntu/.dockerhub_token || { rm -f /home/ubuntu/.dockerhub_token; exit 1; }",
      "rm -f /home/ubuntu/.dockerhub_token",
      "sudo docker pull '${local.docker_image}'",
      "sudo docker rm -f chess || true",
      "sudo docker run --detach --name chess --restart unless-stopped --publish 8080:8080 '${local.docker_image}'",
      "sudo docker logout"
    ]
  }
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

output "subnet-2" {
  value = yandex_vpc_subnet.subnet-2.id
}