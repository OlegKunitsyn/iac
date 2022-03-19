log_level  = "WARN"
data_dir   = "/opt/nomad/data"
region     = "${region}"
datacenter = "${datacenter}"

advertise {
  http = "${advertise_ip}"
  rpc  = "${advertise_ip}"
  serf = "${advertise_ip}"
}

server {
  enabled          = true
  bootstrap_expect = 1
}