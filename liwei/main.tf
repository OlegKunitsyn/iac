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

# Cluster
resource "hcloud_server" "cluster" {
  for_each = {for item in local.nodes :  item.country => item}
  network {
    network_id = hcloud_network.private.id
    ip         = each.value.ip
  }
  depends_on = [
    hcloud_network_subnet.network-subnet
  ]
  location    = each.value.location
  name        = "${each.value.country}.${local.domain_name}"
  image       = "debian-11"
  server_type = "cx11"
  ssh_keys    = [data.hcloud_ssh_key.ssh_key.id]
  user_data   = <<-EOF
#!/bin/bash
apt-get update
apt-get -y install mc psmisc net-tools fail2ban
apt-get -y install npm memcached
systemctl enable fail2ban
systemctl start fail2ban
mkdir /var/www
mkdir /var/www/project
chown www-data:www-data /var/www/project

# memcached
echo '-d
logfile /var/log/memcached.log
-m 4
-p 11211
-u memcache
-l ${each.value.ip}
-P /var/run/memcached/memcached.pid
' > /etc/memcached.conf
systemctl restart memcached

# block port
iptables -A INPUT -d 127.0.0.0/8 -j ACCEPT
iptables -A INPUT -d ${hcloud_network_subnet.network-subnet.ip_range} -j ACCEPT
iptables -A INPUT -p tcp --dport 11211 -j DROP
    EOF
}

# DNS
resource "ovh_domain_zone_record" "root" {
  provider  = ovh.eu
  for_each  = {for item in local.nodes :  item.country => item}
  zone      = local.domain_name
  subdomain = ""
  target    = hcloud_server.cluster[each.key].ipv4_address
  fieldtype = "A"
  ttl       = "3600"
}
resource "ovh_domain_zone_record" "node" {
  provider  = ovh.eu
  for_each  = {for item in local.nodes :  item.country => item}
  zone      = local.domain_name
  subdomain = each.value.country
  target    = hcloud_server.cluster[each.key].ipv4_address
  fieldtype = "A"
  ttl       = "3600"
}

# Deployment
resource "time_sleep" "init" {
  depends_on = [
    hcloud_network_subnet.network-subnet
  ]
  create_duration = "60s"
}
resource "null_resource" "deployment" {
  depends_on = [
    time_sleep.init
  ]
  for_each = {for item in local.nodes :  item.country => item}
  connection {
    type = "ssh"
    user = "root"
    host = hcloud_server.cluster[each.key].ipv4_address
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
      "export MEMCACHED=${join(",", values({for item in local.nodes : item.country => item.ip}))}",
      "nohup node app.js &",
      "sleep 1",
    ]
  }
}