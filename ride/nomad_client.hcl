log_level  = "WARN"
data_dir   = "/opt/nomad/data"
region     = "${region}"
datacenter = "${datacenter}"

advertise {
  http = "${advertise_ip}"
  rpc = "${advertise_ip}"
  serf = "${advertise_ip}"
}

client {
  cni_path       = "/opt/cni/bin"
  cni_config_dir = "/opt/cni/config"
  enabled        = true
  servers        = ["${server_ip}"]
}
