terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  cloud_id    = local.cloud_id
  folder_id   = local.folder_id
}

locals {
  cloud_id    = "b1gh268nmke9btt81pou"
  folder_id   = "b1gslld5kk9vkm5u7prh"
  zone        = "ru-central1-a"
  cidr        = "192.168.1.0/24"
}

# Создание сети

resource "yandex_vpc_network" "coi-instance-network" {
  name = "sample-network"
}

# Создание подсети

resource "yandex_vpc_subnet" "coi-instance-subnet-d" {
  name           = "sample-network-subnet"
  zone           = local.zone
  network_id     = yandex_vpc_network.coi-instance-network.id
  v4_cidr_blocks = [local.cidr]
}

# Создание группы безопасности

resource "yandex_vpc_security_group" "coi-instance-sg" {
  name        = "sample-sg"
  network_id  = yandex_vpc_network.coi-instance-network.id

  ingress {
    protocol       = "TCP"
    description    = "http"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "https"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    protocol       = "TCP"
    description    = "ssh"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  egress {
    protocol       = "ANY"
    description    = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

