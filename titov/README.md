# Titov
Multi-node clustered PHP Symfony setup on VPS with distributed NoSQL database

## Providers
- Hetzner, EU zone
- OVH, EU zone

## Components
- custom `titov-image` created by Packer
- 1 `cx11` node based on `titov-image` selecting `min` workspace, or
- 3 `cx11` nodes based on `titov-image` selecting `max` workspace
- firewall by Hetzner
- `testdomain.ovh` points to VPS via Round-Robin
- `es.testdomain.ovh` provides Round-Robin discovery for ElasticSearch
- private network among all nodes
- ElasticSearch instance on each node
- PHP Symfony 5.4
- Terraform Cloud

## Notes
- http only
- applications store the visits to `http://testdomain.ovh/` in ElasticSearch that you may see at REST endpoint `http://testdomain.ovh/api/visits/`

## Custom image
The image (snapshot in terms of Hetzner) includes
- Nginx 1.18
- PHP 7.4
- PHP-FPM
- OpenJDK 11
- ElasticSearch 2.4.6

Create `devops/image.auto.pkrvars.hcl` file with your secrets
```
# https://console.hetzner.cloud/projects/.../security/tokens
hetzner_token_cloud = "..."
```
then build and publish at Hetzner
```
$ cd devops
$ packer init .
$ packer build .
```

## Provisioning and deployment
In the Terraform Cloud Organization settings add a Variable set containing the secrets
- hetzner_token_cloud
- hetzner_fingerprint
- ovh_application_key
- ovh_application_secret
- ovh_consumer_key

and initialize two workspaces
```
$ cd devops
$ terraform init
$ terraform workspace new min
$ terraform workspace new max
```

### Deploy single-node
```
$ terraform workspace select min
$ terraform apply -auto-approve
```

### Deploy multi-node
```
$ terraform workspace select max
$ terraform apply -auto-approve
```

## Credits
- https://www.packer.io/plugins/builders/hetzner-cloud
