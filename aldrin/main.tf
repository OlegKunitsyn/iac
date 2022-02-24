terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    ovh = {
      source = "ovh/ovh"
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
  type = string
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

# Load balancer
resource "hcloud_load_balancer" "lb" {
  name               = "lb"
  load_balancer_type = "lb11"
  location           = local.location
}
resource "hcloud_load_balancer_network" "network" {
  load_balancer_id = hcloud_load_balancer.lb.id
  network_id       = hcloud_network.private.id
  ip               = local.lb_private_ip
}
resource "hcloud_load_balancer_service" "settings" {
  load_balancer_id = hcloud_load_balancer.lb.id
  protocol         = "http"
  listen_port      = 80
  destination_port = 8000
  health_check {
    interval = 3
    timeout  = 1
    retries  = 0
    port     = 8000
    protocol = "http"
    http {
      path = "/actuator/health"
    }
  }
}
resource "hcloud_load_balancer_target" "apps" {
  count            = length(hcloud_server.apps)
  type             = "server"
  load_balancer_id = hcloud_load_balancer.lb.id
  server_id        = hcloud_server.apps[count.index].id
  use_private_ip   = true
}

# Database node
resource "hcloud_server" "db" {
  network {
    network_id = hcloud_network.private.id
    ip         = local.db_private_ip
  }
  depends_on = [
    hcloud_network_subnet.network-subnet
  ]
  lifecycle {
    prevent_destroy = true
  }
  location    = local.location
  name        = "db"
  image       = "debian-11"
  server_type = "cx11"
  ssh_keys    = [data.hcloud_ssh_key.ssh_key.id]
  user_data   = <<-EOF
#!/bin/bash
apt-get update
apt-get -y install psmisc mc net-tools fail2ban
apt-get -y install openjdk-11-jdk-headless
systemctl enable fail2ban
systemctl start fail2ban
mkdir /var/www
mkdir /var/www/project
chown www-data:www-data /var/www/project

# hsqldb service
wget https://repo1.maven.org/maven2/org/hsqldb/hsqldb/2.6.1/hsqldb-2.6.1.jar -O /var/www/project/hsqldb.jar
echo '${file("hsqldb.service")}' > /etc/systemd/system/hsqldb.service
systemctl daemon-reload
systemctl enable hsqldb.service
systemctl start hsqldb.service
    EOF
}

# Application nodes
resource "hcloud_server" "apps" {
  count      = local.app_nodes
  depends_on = [
    hcloud_network_subnet.network-subnet
  ]
  lifecycle {
    create_before_destroy = true
  }
  network {
    network_id = hcloud_network.private.id
    ip         = replace(local.app_private_ip, "X", count.index)
  }
  location    = local.location
  name        = "app-${count.index}"
  image       = "debian-11"
  server_type = "cx11"
  ssh_keys    = [data.hcloud_ssh_key.ssh_key.id]
  user_data   = <<-EOF
#!/bin/bash
apt-get update
apt-get -y install psmisc mc net-tools fail2ban
apt-get -y install openjdk-11-jdk-headless
systemctl enable fail2ban
systemctl start fail2ban
mkdir /var/www
mkdir /var/www/project
chown www-data:www-data /var/www/project

# app service
echo '${file("app.service")}' > /etc/systemd/system/app.service
systemctl daemon-reload
systemctl enable app.service
    EOF
}

# DNS
resource "ovh_domain_zone_record" "root" {
  zone      = local.domain_name
  subdomain = ""
  target    = hcloud_load_balancer.lb.ipv4
  fieldtype = "A"
  ttl       = "3600"
}
resource "ovh_domain_zone_record" "db" {
  zone      = local.domain_name
  subdomain = "db"
  target    = local.db_private_ip
  fieldtype = "A"
  ttl       = "3600"
}

# Deployment
resource "null_resource" "boot-finished" {
  depends_on = [hcloud_network_subnet.network-subnet]
  count = length(hcloud_server.apps)
  connection {
    type = "ssh"
    user = "root"
    host = hcloud_server.apps[count.index].ipv4_address
  }
  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 5; done"
    ]
  }
}
resource "null_resource" "deployment" {
  depends_on = [null_resource.boot-finished]
  triggers   = {
    version = var.project_version
  }
  count = length(hcloud_server.apps)
  connection {
    type = "ssh"
    user = "root"
    host = hcloud_server.apps[count.index].ipv4_address
  }
  provisioner "file" {
    source      = "target/project-${var.project_version}.jar"
    destination = "/var/www/project/app.jar"
  }
  provisioner "remote-exec" {
    inline = [
      "cd /var/www/project",
      "systemctl restart app.service",
      "sleep 1",
    ]
  }
}

output "url" {
  description = "Project URL"
  value       = "http://${local.domain_name}"
}
output "apps_public" {
  description = "Application IPs"
  value       = hcloud_server.apps[*].ipv4_address
}
output "db_public" {
  description = "Database public IP"
  value       = hcloud_server.db.ipv4_address
}
output "db_private" {
  description = "Database private IP"
  value       = local.db_private_ip
}
