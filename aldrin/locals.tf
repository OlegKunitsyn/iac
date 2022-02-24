locals {
  domain_name    = "testdomain.ovh"
  location       = "fsn1"
  lb_private_ip  = "10.0.0.2"
  app_private_ip = "10.0.1.X"
  db_private_ip  = "10.0.1.254"
  app_nodes      = 2
}
