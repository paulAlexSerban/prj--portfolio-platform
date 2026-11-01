# Foundation

Owner: platform. Change cadence: rare. Blast radius: high.

AWS accounts, IAM, the DNS zone, and the Terraform state bucket live here. A mistake in this layer affects every other layer.

## Contents

- `bootstrap/`: creates the S3 bucket used as the Terraform state backend.
- `terraform/dns-zone/`: the public hosted zone for `paulserban.eu` and its ownership records. State key is `portfolio-platform/terraform.tfstate` and stays that way so the existing state does not move.
- `terraform/github-oidc-provider/`: the one GitHub Actions OIDC provider for this account. State key is `01-foundation/github-oidc/prod.tfstate`. Apply it before the static-sites stack. The deploy roles look the provider up and do not create a second one.

```bash
make terraform-bootstrap-state-bucket
make terraform-dns-zone-init
make terraform-dns-zone-plan
make terraform-oidc-init
make terraform-oidc-plan
```
