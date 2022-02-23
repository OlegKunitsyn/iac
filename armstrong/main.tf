terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    ovh    = {
      source = "ovh/ovh"
    }
  }
}

locals {
  domain_name = "testdomain.ovh"
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

provider "hcloud" {
  token = var.hetzner_token_cloud
}
provider "ovh" {
  endpoint           = "ovh-eu"
  application_key    = var.ovh_application_key
  application_secret = var.ovh_application_secret
  consumer_key       = var.ovh_consumer_key
}

# Node
resource "hcloud_server" "node" {
  name        = local.domain_name
  image       = "debian-11"
  server_type = "cx11"
  datacenter  = "fsn1-dc14"
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

# setup traefik
mkdir /var/www/html
wget https://github.com/traefik/traefik/releases/download/v2.6.0/traefik_v2.6.0_linux_amd64.tar.gz
tar -zxvf traefik_v2.6.0_linux_amd64.tar.gz
chmod +x traefik
cp ./traefik /usr/local/bin
chown root:root /usr/local/bin/traefik
chmod 755 /usr/local/bin/traefik
setcap 'cap_net_bind_service=+ep' /usr/local/bin/traefik
groupadd -g 321 traefik
useradd -g traefik --no-user-group --home-dir /var/www/html --no-create-home --shell /usr/sbin/nologin --system --uid 321 traefik
#usermod -aG traefik
mkdir /etc/traefik
mkdir /etc/traefik/acme
mkdir /etc/traefik/dynamic
chown -R root:root /etc/traefik
chown -R traefik:traefik /etc/traefik/dynamic /etc/traefik/acme
mkdir /var/log/traefik
touch /var/log/traefik/error.log
touch /var/log/traefik/access.log
chown traefik:traefik /var/log/traefik/ /var/log/traefik/access.log /var/log/traefik/error.log
echo '[log]
  level = "ERROR"
  filePath = "/var/log/traefik/error.log"
[accessLog]
  filePath =  "/var/log/traefik/access.log"
  bufferingSize =  100
[providers]
  [providers.file]
    filename = "/etc/traefik/traefik-dynamic.toml"
[api]
  dashboard = false
  debug = false
[entryPoints]
  [entryPoints.insecure]
    address = ":80"
  [entryPoints.secure]
    address = ":443"
[certificatesResolvers.sample.acme]
  email = "info@${local.domain_name}"
  storage = "/etc/traefik/acme/acme.json"
  [certificatesResolvers.sample.acme.httpChallenge]
    entryPoint = "insecure"
' > /etc/traefik/traefik.toml
echo '[http]
  [http.routers]
    [http.routers.https]
      rule = "Host(`${local.domain_name}`)"
      service = "project"
      entryPoints = ["secure"]
    [http.routers.https.tls]
      certResolver = "sample"
    [http.routers.http]
      rule = "Host(`${local.domain_name}`)"
      service = "project"
      entryPoints = ["insecure"]
[http.services]
    [http.services.project.loadbalancer]
    [http.services.project.loadbalancer.healthCheck]
      path = "/"
      interval = "1s"
      timeout = "1s"
      [[http.services.project.loadbalancer.servers]]
        url = "http://127.0.0.1:8000"
      [[http.services.project.loadbalancer.servers]]
        url = "http://127.0.0.1:8001"
' > /etc/traefik/traefik-dynamic.toml
echo '[Unit]
Description=traefik proxy
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service
[Service]
Restart=on-abnormal
User=traefik
Group=traefik
ExecStart=/usr/local/bin/traefik --configfile=/etc/traefik/traefik.toml
LimitNOFILE=1048576
PrivateTmp=true
PrivateDevices=false
ProtectHome=true
ProtectSystem=full
ReadWriteDirectories=/etc/traefik/acme
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
[Install]
WantedBy=multi-user.target
' > /etc/systemd/system/traefik.service
chown root:root /etc/systemd/system/traefik.service
chmod 644 /etc/systemd/system/traefik.service
systemctl daemon-reload
systemctl enable traefik.service
systemctl start traefik.service

# block ports
iptables -A INPUT -d 127.0.0.0/8 -j ACCEPT
iptables -A INPUT -p tcp --dport 8000 -j DROP
iptables -A INPUT -p tcp --dport 8001 -j DROP
    EOF
}

# Waiting for cloud-init
resource "null_resource" "boot-finished" {
  connection {
    type        = "ssh"
    user        = "root"
    host        = hcloud_server.node.ipv4_address
  }
  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 5; done"
    ]
  }
}

# Deployment
resource "null_resource" "deployment" {
  depends_on = [null_resource.boot-finished]
  triggers = {
    version = var.project_version
  }
  connection {
    type        = "ssh"
    user        = "root"
    host        = hcloud_server.node.ipv4_address
  }
  provisioner "file" {
    source      = "target/project-${var.project_version}-jar-with-dependencies.jar"
    destination = "/var/www/project/project-${var.project_version}.jar"
  }
  provisioner "remote-exec" {
    inline = [
      "cd /var/www/project",
      "nohup sudo -u www-data java -jar project-${var.project_version}.jar > /dev/null 2>&1 &",
      "killall -q -o 10s -u www-data",
      "sleep 5"
    ]
  }
}

# DNS
resource "ovh_domain_zone_record" "root" {
  zone      = local.domain_name
  subdomain = ""
  target    = hcloud_server.node.ipv4_address
  fieldtype = "A"
  ttl       = "3600"
}

output "ip" {
  description = "Public IP"
  value       = hcloud_server.node.ipv4_address
}
output "url" {
  description = "Project URL"
  value       = "https://${local.domain_name}"
}
output "version" {
  description = "Project version"
  value       = var.project_version
}
output "status" {
  description = "Server status"
  value       = hcloud_server.node.status
}
