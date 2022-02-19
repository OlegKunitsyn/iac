locals {
  domain_name = "testdomain.ovh"
  nodes       = [
    {
      country  = "de"
      location = "fsn1"
      ip       = "10.0.0.2"
    },
    {
      country  = "fi"
      location = "hel1"
      ip       = "10.0.0.3"
    }
  ]
}
