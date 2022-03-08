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

locals {
  cluster_size = 2
  domain_name  = "testdomain.ovh"
  location    = "fsn1"
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
      source_ips = ["0.0.0.0/0", "::/0"]
      port       = "443"
    },
  ]
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

# Cluster
resource "hcloud_server" "cluster" {
  count = local.cluster_size
  location    = local.location
  name        = "node-${count.index}"
  image       = "debian-11"
  server_type = "cx11"
  ssh_keys    = [data.hcloud_ssh_key.ssh_key.id]
  firewall_ids = [hcloud_firewall.firewall.id]
}
resource "null_resource" "setup" {
  count      = local.cluster_size
  connection {
    type = "ssh"
    user = "root"
    host = hcloud_server.cluster[count.index].ipv4_address
  }
  provisioner "remote-exec" {
    inline = [
      "apt-get -y install debian-keyring debian-archive-keyring gnupg",
      "curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | apt-key add -",
      "curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list",
      "apt-get update",
      "apt-get -y install mc psmisc net-tools fail2ban npm caddy",
      "systemctl enable fail2ban",
      "systemctl start fail2ban",
      "systemctl enable caddy",
    ]
  }
  provisioner "file" {
    content      = templatefile("Caddyfile", {
      domain = local.domain_name
    })
    destination = "/etc/caddy/Caddyfile"
  }
  provisioner "remote-exec" {
    inline = [
      "systemctl restart caddy",
    ]
  }
}

# DNS
resource "ovh_domain_zone_record" "root" {
  count     = local.cluster_size
  zone      = local.domain_name
  subdomain = ""
  target    = hcloud_server.cluster[count.index].ipv4_address
  fieldtype = "A"
  ttl       = "3600"
}

# Deployment
resource "null_resource" "deployment" {
  depends_on = [null_resource.setup]
  count      = local.cluster_size
  connection {
    type = "ssh"
    user = "root"
    host = hcloud_server.cluster[count.index].ipv4_address
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir /var/www",
      "mkdir /var/www/project",
      "chown www-data:www-data /var/www/project",
    ]
  }
  provisioner "file" {
    source      = "package.json"
    destination = "/var/www/project/package.json"
  }
  provisioner "file" {
    source      = "app.js"
    destination = "/var/www/project/app.js"
  }
  provisioner "remote-exec" {
    inline = [
      "cd /var/www/project",
      "npm install",
      "killall -q node",
      "nohup sudo -u www-data node app.js &",
      "sleep 1",
    ]
  }
}

output "ip" {
  description = "Public IPs"
  value       = hcloud_server.cluster.*.ipv4_address
}
output "url" {
  description = "Project URL"
  value       = "https://${local.domain_name}"
}
output "status" {
  description = "Server statuses"
  value       = hcloud_server.cluster.*.status
}
