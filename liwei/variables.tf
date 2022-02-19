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
