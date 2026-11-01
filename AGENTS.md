# Portfolio Platform

Terraform for the AWS account that hosts paulserban.eu. Application source stays in the product repositories. This repo provisions DNS, the static-site hosting, and the roles those repositories assume.

## Layout

| Path | What it is |
| --- | --- |
| `layers/01-foundation` | State bucket bootstrap, the Route 53 zone, the GitHub OIDC provider |
| `layers/02-compute` through `layers/06-cross-cutting` | Reserved. See each README. |
| `layers/05-workloads/terraform/static-sites` | Portfolio, blog, quiz, news-feed, and the news JSON CDN |
| `modules/terraform` | Shared modules those stacks call |
| `_docs/` | Spikes, plans, and the cutover runbook |
| `scripts/` | One-time migration scripts and local helpers |

## Commands

Load `.env` yourself (`set -a && source .env && set +a`). The makefile targets do not source it.

```bash
make terraform-bootstrap-state-bucket
make terraform-dns-zone-init
make terraform-dns-zone-plan
make terraform-oidc-init
make terraform-oidc-apply
make terraform-static-sites-init
make terraform-static-sites-plan
make terraform-static-sites-apply
make sync-github-env-vars
```

`make terraform-static-sites-certs` creates the ACM certificates without attaching hostnames. The cutover order is in `_docs/02--plans/portfolio-cutover.md`.

## Conventions

- One Terraform state per stack, in the platform state bucket, with native S3 locking (`use_lockfile = true`). No DynamoDB lock table.
- New state keys are `<layer>/<stack>/<env>.tfstate`. The DNS zone keeps its existing key, `portfolio-platform/terraform.tfstate`.
- Provider `hashicorp/aws` is pinned `~> 5.70`. Terraform is pinned in `.terraform-version`.
- Tags on the portfolio stack are `project`, `env`, `owner`, and `cost-center`.
- No long-lived AWS keys in GitHub. Workflows assume an OIDC role. Secrets stay out of git. `.env` and `terraform.tfvars` are gitignored.
