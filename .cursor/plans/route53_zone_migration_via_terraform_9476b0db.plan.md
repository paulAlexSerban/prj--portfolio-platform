---
name: Route53 Zone Migration via Terraform
overview: Transform the exported Route 53 record set JSON for `paulserban.eu` into a data-driven Terraform configuration under `layers/01-foundation/terraform/dns-zone/`, provisioning the hosted zone and its non-infrastructure DNS/SEO records (verification, DMARC, DKIM, ACM validation) in the target AWS account using credentials from `.env`. CloudFront alias (A/AAAA) records and S3 buckets are out of scope — they will be recreated and wired up separately.
todos:
  - id: main-tf
    content: Write terraform/provider block in main.tf
    status: completed
  - id: variables
    content: Add variables.tf with domain_name
    status: completed
  - id: zone
    content: Add route53_zone.tf with aws_route53_zone resource
    status: completed
  - id: records
    content: Add route53_records.tf transforming the non-CloudFront JSON records (CNAME/TXT) into a for_each resource
    status: completed
  - id: outputs
    content: Add outputs.tf exposing zone_id and name_servers
    status: completed
isProject: false
---

## Source data
[tmp/route53-resource-record-sets-Z0098660U3Z7GN6KH4L1.json](tmp/route53-resource-record-sets-Z0098660U3Z7GN6KH4L1.json) contains 32 record sets for zone `paulserban.eu`:
- 7 alias name groups x (A + AAAA) -> CloudFront distributions (apex, `assets`, `blog`, `news-data`, `news-feed`, `quiz`, `www`) — **out of scope for this plan**, since these point at CloudFront distributions (backed by S3 buckets) that will be recreated and wired up in a separate piece of work
- 1 apex `NS` and 1 apex `SOA` record — **excluded**, `aws_route53_zone` auto-creates these, and the whole point of the migration is to get the *new* account's name servers (needed later for delegation switch), so importing the old ones would be wrong/conflicting
- The remaining 15 records are plain `CNAME`/`TXT` "SEO/ownership config" records, unrelated to CloudFront/S3: Bing site-verification CNAMEs (apex, `blog`, `news-feed`, `www`), ACM DNS-validation CNAMEs (apex, `assets`, `blog`, `news-data`, `news-feed`, `quiz`, `www`), apex `TXT` (Google site-verification), and `_dmarc` `TXT` — **these are the scope of this plan**
- All Klaviyo references (apex `TXT` `klaviyo-site-verification`, `kl1`/`kl2._domainkey` CNAMEs) have been removed from the source JSON and are excluded entirely

This plan creates **only** the hosted zone plus these 15 CNAME/TXT records. No `aws_route53_record` with an `alias` block, no CloudFront, no S3, no Klaviyo resources are included here.

## Credentials / provider
[.env.example](.env.example) defines `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` — these are the standard env var names the Terraform `aws` provider auto-detects, so no explicit credentials block is needed:

```hcl
provider "aws" {}
```

User runs `set -a && source .env && set +a` (per existing [makefile](makefile) target `source-env-file`) before `terraform plan/apply`, pointing at the target account.

## Files to create in `layers/01-foundation/terraform/dns-zone/`
- `main.tf` (currently empty) — `terraform {}` block with `required_version` + `required_providers { aws }`, and `provider "aws" {}`
- `variables.tf` — `variable "domain_name"` (default `"paulserban.eu"`)
- `route53_zone.tf` — the hosted zone:
  ```hcl
  resource "aws_route53_zone" "this" {
    name    = var.domain_name
    comment = var.domain_name
  }
  ```
- `route53_records.tf` — data-driven records, transformed from the JSON (CloudFront alias records intentionally omitted):
  - `locals.dns_records` map (keyed by a descriptive id, e.g. `bing_verify_apex`, `acm_validation_assets`, `dmarc`, `google_site_verification`, ...) of the CNAME/TXT records with `name`, `type`, `ttl`, `records`, consumed by one `for_each` `aws_route53_record.dns` resource:
    ```hcl
    resource "aws_route53_record" "dns" {
      for_each = local.dns_records
      zone_id  = aws_route53_zone.this.zone_id
      name     = each.value.name
      type     = each.value.type
      ttl      = each.value.ttl
      records  = each.value.records
    }
    ```
- `outputs.tf` — `output "zone_id"` and `output "name_servers"` (from `aws_route53_zone.this.name_servers`), needed for the later delegation switch step in [01 migrate domain between aws accounts.md](_docs/00--ideas/01%20migrate%20domain%20between%20aws%20accounts.md)

No remote state backend will be configured (local state is sufficient for this one-time migration).

## Verification (not executed automatically in plan mode)
After apply, compare `terraform output name_servers` and the record set against the original export (e.g. `aws route53 list-resource-record-sets` on the new zone) before switching delegation.
