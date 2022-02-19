output "ip" {
  description = "Public IPs"
  value       = {for node in hcloud_server.cluster : node.name => node.ipv4_address}
}
output "url" {
  description = "Project URL"
  value       = "http://${local.domain_name}"
}
output "status" {
  description = "Server statuses"
  value       = values(hcloud_server.cluster)[*].status
}
