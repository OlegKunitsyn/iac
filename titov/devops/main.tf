terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    ovh = {
      source = "ovh/ovh"
    }
  }
  backend "remote" {
    organization = "OlegKunitsyn"
    hostname     = "app.terraform.io"
    workspaces {
      prefix = "titov-"
    }
  }
}
provider "hcloud" {
  token = var.hetzner_token_cloud
}
provider "ovh" {
  endpoint           = "ovh-eu"
  application_key    = var.ovh_application_key
  application_secret = var.ovh_application_secret
  consumer_key       = var.ovh_consumer_key
}

locals {
  location        = "fsn1"
  image           = "titov-image"
  domain_name     = "testdomain.ovh"
  node_private_ip = "10.0.0.X"
  ingress_rules   = [
    {
      source_ips = ["0.0.0.0/0", "::/0"]
      port       = "22"
    },
    {
      source_ips = ["0.0.0.0/0", "::/0"]
      port       = "80"
    },
    {
      source_ips = [hcloud_network_subnet.network-subnet.ip_range]
      port       = "9200"
    },
    {
      source_ips = [hcloud_network_subnet.network-subnet.ip_range]
      port       = "9300"
    }
  ]
  count = terraform.workspace == "titov-min" ? 1 : 3
}
variable "hetzner_token_cloud" {
  type = string
}
variable "hetzner_fingerprint" {
  type = string
}
data "hcloud_ssh_key" "ssh_key" {
  fingerprint = var.hetzner_fingerprint
}
variable "ovh_application_key" {
  type = string
}
variable "ovh_application_secret" {
  type = string
}
variable "ovh_consumer_key" {
  type = string
}
variable "project_version" {
  type    = string
  default = "1.0.1"
}

# Network
resource "hcloud_network" "private" {
  name     = "private"
  ip_range = "10.0.0.0/8"
}
resource "hcloud_network_subnet" "network-subnet" {
  type         = "server"
  network_id   = hcloud_network.private.id
  network_zone = "eu-central"
  ip_range     = "10.0.0.0/16"
}

# Firewall
resource "hcloud_firewall" "firewall" {
  name = local.domain_name
  dynamic "rule" {
    for_each = local.ingress_rules
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = rule.value.port
      source_ips = rule.value.source_ips
    }
  }
}

# DNS
resource "ovh_domain_zone_record" "root" {
  count     = local.count
  zone      = local.domain_name
  subdomain = ""
  target    = hcloud_server.nodes[count.index].ipv4_address
  fieldtype = "A"
  ttl       = "3600"
}
resource "ovh_domain_zone_record" "es" {
  count     = local.count
  zone      = local.domain_name
  subdomain = "es"
  target    = replace(local.node_private_ip, "X", count.index + 2)
  fieldtype = "A"
  ttl       = "30"
}

# Nodes
data "hcloud_image" "image" {
  most_recent = true
  with_selector = "name=${local.image}"
}
resource "hcloud_server" "nodes" {
  count      = local.count
  depends_on = [
    hcloud_network_subnet.network-subnet
  ]
  network {
    network_id = hcloud_network.private.id
    ip         = replace(local.node_private_ip, "X", count.index + 2)
  }
  firewall_ids = [hcloud_firewall.firewall.id]
  location     = local.location
  name         = "node-${count.index}"
  image        = data.hcloud_image.image.id
  server_type  = "cx11"
  ssh_keys     = [data.hcloud_ssh_key.ssh_key.id]
  user_data    = <<-EOF
#!/bin/bash
apt-get -y install git
mkdir /var/www/project
cd /var/www/project
git clone https://github.com/OlegKunitsyn/iac.git
chown www-data:www-data /var/www/project/iac/titov
echo '${templatefile("nginx.conf", { server_name = local.domain_name, root = "/var/www/project/iac/titov/public" })}' > /etc/nginx/sites-enabled/project.conf
echo '${templatefile("elasticsearch.yml", { cluster_name = local.domain_name, node_name = "node-${count.index}", unicast_hosts = "es.${local.domain_name}", node_private_ip = replace(local.node_private_ip, "X", count.index + 2), })}' > /etc/elasticsearch/elasticsearch.yml
systemctl restart elasticsearch
systemctl restart php7.4-fpm
systemctl restart nginx
    EOF
}

output "ip" {
  description = "Public IPs"
  value       = {for node in hcloud_server.nodes : node.name => node.ipv4_address}
}
output "url" {
  description = "Project URL"
  value       = "http://${local.domain_name}"
}
output "workspace" {
  description = "Workspace name"
  value       = terraform.workspace
}
output "status" {
  description = "Server statuses"
  value       = hcloud_server.nodes[*].status
}
