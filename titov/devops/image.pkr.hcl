packer {
  required_plugins {
    hcloud = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/hcloud"
    }
  }
}

locals {
  location = "fsn1"
  image    = "titov-image"
}
variable "hetzner_token_cloud" {
  type = string
}

source "hcloud" "titov" {
  token         = var.hetzner_token_cloud
  location      = local.location
  server_type   = "cx11"
  image         = "debian-11"
  ssh_username  = "root"
  server_name   = "debian-11"
  snapshot_name = local.image
  snapshot_labels = {
    "name" = local.image
  }
}

build {
  name    = local.image
  sources = [
    "source.hcloud.titov"
  ]
  provisioner "shell" {
    inline = [
      "echo 'deb [trusted=yes] https://repo.symfony.com/apt/ /' | tee /etc/apt/sources.list.d/symfony-cli.list",
      "apt-get update",
      "apt-get -y install unzip psmisc mc net-tools fail2ban openjdk-11-jre-headless nginx",
      "apt-get -y install php php-cli php-fpm php-xml php-mbstring php-iconv symfony-cli",
      "wget https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/deb/elasticsearch/2.4.6/elasticsearch-2.4.6.deb -O elasticsearch.deb",
      "apt-get -y install ./elasticsearch.deb",
      "echo '${templatefile("elasticsearch.yml", { cluster_name = "cluster", node_name = "node", unicast_hosts = "localhost", node_private_ip = "127.0.1.1" })}' > /etc/elasticsearch/elasticsearch.yml",
      "echo '${file("elasticsearch.in.sh")}' > /usr/share/elasticsearch/bin/elasticsearch.in.sh",
      "systemctl enable fail2ban",
      "systemctl enable php7.4-fpm",
      "systemctl enable nginx",
    ]
  }
}
