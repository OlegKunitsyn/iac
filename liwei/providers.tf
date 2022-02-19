terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    ovh = {
      source = "ovh/ovh"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}
provider "hcloud" {
  token = var.hetzner_token_cloud
}
provider "ovh" {
  alias              = "eu"
  endpoint           = "ovh-eu"
  application_key    = var.ovh_application_key
  application_secret = var.ovh_application_secret
  consumer_key       = var.ovh_consumer_key
}