log_level  = "WARN"
data_dir   = "/opt/consul/data"
datacenter = "${datacenter}"

bind_addr = "${bind_addr}"
addresses {
  grpc = "${grpc}"
  http = "${http}"
  dns  = "${dns}"
}
ui         = false
server     = false
retry_join = ["${server_ip}"]

# Mesh
ports {
  grpc = 8502
}
connect {
  enabled = true
}

verify_incoming        = false
verify_outgoing        = false
verify_server_hostname = false
