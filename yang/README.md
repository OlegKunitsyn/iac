# Yang
Multi-node plain Node.js setup on VPS with TLS termination

## Providers
- Hetzner, EU zone
- OVH, EU zone

## Components
- `testdomain.ovh` points to two `cx11` VPS via Round-Robin DNS
- firewall by Hetzner
- Node.js 14
- Express.js 4 application
- Caddy 2.4

## Notes
- HTTPS by default
- application instances share nothing

## Provisioning
Create `terraform.tfvars` file with your secrets
```
# https://console.hetzner.cloud/projects/.../security/tokens
hetzner_token_cloud = "..."
# https://console.hetzner.cloud/projects/.../security/sshkeys
hetzner_fingerprint = "..."
# https://api.ovh.com/createToken/?GET=/*&POST=/*&PUT=/*&DELETE=/*
ovh_application_key = "..."
ovh_application_secret = "..."
ovh_consumer_key = "..."
```
then
```
$ terraform init
$ terraform apply -auto-approve
ip = [
  "<IP1>",
  "<IP2>",
]
status = [
  "running",
  "running",
]
url = "https://testdomain.ovh"
```

## TLS test
```
$ curl --resolve testdomain.ovh:443:<IP1> https://testdomain.ovh
Client ... processed by node-0
$ curl --resolve testdomain.ovh:443:<IP2> https://testdomain.ovh
Client ... processed by node-1
```
