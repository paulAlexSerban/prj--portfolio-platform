# IDEA: Migrate domain between AWS accounts

- Export all record sets from the source account.
  - use AWS CLI to export the DNS zone config from SOURCE account to TARGET account
  - run `bash scripts/one-time/export-route53-dns-zone-config.bash`

- build up terraform module that provisions the DNS zone in the TARGET account
- Transform the JSON into Terraform resources.
- Create the hosted zone in the destination account.
- Create all DNS records using Terraform.
- Compare source and destination records.
- Switch the domain delegation to the new name servers.