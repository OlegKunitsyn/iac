terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    nomad = {
      source = "hashicorp/nomad"
    }
  }
}
provider "nomad" {
  address = "http://${hcloud_server.server.ipv4_address}:4646"
  region  = local.region
}
provider "hcloud" {
  token = var.hetzner_token_cloud
}

locals {
  domain_name    = "testdomain.ovh"
  nomad_clients  = 2
  private_ip     = "10.0.0.X"
  datacenter     = "dc14"
  location       = "fsn1"
  region         = "eu"
  gitlab_project = 34479081
  ingress_rules  = [
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
      port       = "4646"
    },
    {
      source_ips = ["0.0.0.0/0", "::/0"]
      port       = "8500"
    }
  ]
}
variable "hetzner_token_cloud" {
  type = string
}
variable "project_version" {
  type    = string
  default = "1.0.1"
}
variable "hetzner_fingerprint" {
  type = string
}
data "hcloud_ssh_key" "ssh_key" {
  fingerprint = var.hetzner_fingerprint
}

# Network
resource "hcloud_network" "private" {
  name     = "private"
  ip_range = "10.0.0.0/16"
}
resource "hcloud_network_subnet" "network-subnet" {
  type         = "server"
  network_id   = hcloud_network.private.id
  network_zone = "eu-central"
  ip_range     = "10.0.0.0/24"
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

# Server
resource "hcloud_server" "server" {
  depends_on  = [hcloud_network_subnet.network-subnet]
  name        = "server"
  image       = "centos-stream-8"
  server_type = "cx11"
  datacenter  = "${local.location}-${local.datacenter}"
  ssh_keys    = [data.hcloud_ssh_key.ssh_key.id]
  network {
    network_id = hcloud_network.private.id
    ip         = replace(local.private_ip, "X", 2)
  }
  #firewall_ids = [hcloud_firewall.firewall.id]
}
resource "null_resource" "server-setup" {
  depends_on = [hcloud_server.server]
  connection {
    type = "ssh"
    user = "root"
    host = hcloud_server.server.ipv4_address
  }
  provisioner "remote-exec" {
    inline = [
      "yum install -y yum-utils",
      "yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo",
      "yum -y install nomad consul mc net-tools",
      "systemctl enable nomad",
      "systemctl enable consul",
    ]
  }
}
resource "null_resource" "server-config" {
  depends_on = [null_resource.server-setup]
  connection {
    type = "ssh"
    user = "root"
    host = hcloud_server.server.ipv4_address
  }
  provisioner "file" {
    content = templatefile("nomad_server.hcl", {
      advertise_ip       = hcloud_server.server.ipv4_address
      datacenter = local.datacenter
      region     = local.region
    })
    destination = "/etc/nomad.d/nomad.hcl"
  }
  provisioner "file" {
    content = templatefile("consul_server.hcl", {
      bind_addr  = hcloud_server.server.ipv4_address
      grpc = "0.0.0.0"
      http = "0.0.0.0"
      dns = "0.0.0.0"
      datacenter = local.datacenter
    })
    destination = "/etc/consul.d/consul.hcl"
  }
  provisioner "remote-exec" {
    inline = [
      "systemctl restart nomad",
      "systemctl restart consul",
      "sleep 3",
      "nomad node status",
    ]
  }
}

# Clients
resource "hcloud_server" "clients" {
  depends_on  = [hcloud_network_subnet.network-subnet]
  count       = local.nomad_clients
  name        = "client-${count.index}"
  image       = "centos-stream-8"
  server_type = "cx11"
  datacenter  = "${local.location}-${local.datacenter}"
  ssh_keys    = [data.hcloud_ssh_key.ssh_key.id]
  network {
    network_id = hcloud_network.private.id
    ip         = replace(local.private_ip, "X", count.index + 3)
  }
  #firewall_ids = [hcloud_firewall.firewall.id]
  user_data    = <<-EOF
#!/bin/bash
echo '
net.bridge.bridge-nf-call-arptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
' > /etc/sysctl.d/cni
    EOF
}
resource "null_resource" "clients-setup" {
  depends_on = [null_resource.server-config]
  count      = local.nomad_clients
  connection {
    type = "ssh"
    user = "root"
    host = hcloud_server.clients[count.index].ipv4_address
  }
  provisioner "remote-exec" {
    inline = [
      "yum install -y yum-utils",
      "yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo",
      "yum -y install nomad consul java-11-openjdk-headless mc net-tools tar",
      "curl -L -o cni-plugins.tgz https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz",
      "mkdir -p /opt/cni/bin",
      "tar -C /opt/cni/bin -xzf cni-plugins.tgz",
      "dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo",
      "dnf -y install docker-ce",
      "systemctl enable docker",
      "systemctl start docker",
      "systemctl enable nomad",
      "systemctl enable consul",
    ]
  }
}
resource "null_resource" "clients-config" {
  depends_on = [null_resource.clients-setup]
  count = local.nomad_clients
  connection {
    type = "ssh"
    user = "root"
    host = hcloud_server.clients[count.index].ipv4_address
  }
  provisioner "file" {
    content = templatefile("nomad_client.hcl", {
      advertise_ip  = hcloud_server.clients[count.index].ipv4_address
      server_ip  = hcloud_server.server.ipv4_address
      datacenter = local.datacenter
      region     = local.region
    })
    destination = "/etc/nomad.d/nomad.hcl"
  }
  provisioner "file" {
    content = templatefile("consul_client.hcl", {
      bind_addr  = hcloud_server.clients[count.index].ipv4_address
      grpc = "0.0.0.0"
      http = "127.0.0.1"
      dns = "127.0.0.1"
      server_ip  = hcloud_server.server.ipv4_address
      datacenter = local.datacenter
    })
    destination = "/etc/consul.d/consul.hcl"
  }
  provisioner "remote-exec" {
    inline = [
      "systemctl restart nomad",
      "systemctl restart consul",
      "sleep 3",
      "nomad node status",
      "consul members",
    ]
  }
}

# Deployment
resource "nomad_job" "deployment" {
  depends_on = [null_resource.clients-config]
  jobspec    = templatefile("deployment.hcl", {
    version    = var.project_version
    datacenter = local.datacenter
    project    = local.gitlab_project
  })
}

output "nomad" {
  description = "Nomad server"
  value       = "http://${hcloud_server.server.ipv4_address}:4646"
}
output "clients" {
  description = "Nomad clients"
  value       = hcloud_server.clients.*.ipv4_address
}
output "consul" {
  description = "Consul server"
  value       = "http://${hcloud_server.server.ipv4_address}:8500"
}