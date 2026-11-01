# Portfolio Platform

DNS for `paulserban.eu` is migrated between AWS accounts with the AWS CLI and Terraform. Terraform state lives in an S3 bucket in the target account.

## Prerequisites

- AWS CLI, Terraform `>= 1.10`, and `jq`
- `make setup-local-project-deps` installs the pinned AWS CLI and Terraform versions

Copy the env template and fill in real values:

```bash
cp .env.example .env
```

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
TF_STATE_BUCKET
```

Load it in the current shell. Repeat this whenever `.env` changes, including when switching accounts:

```bash
set -a && source .env && set +a
```

The export talks to the **source** account. The state bucket and the new hosted zone are created in the **target** account. Point `.env` at the account for the step you are running, then source it again.

## 1. Export the Route 53 zone from the source account

With source-account credentials loaded:

```bash
bash scripts/one-time/export-route53-dns-zone-config.bash
```

This writes every hosted zone in that account to `tmp/`:

- `tmp/route53-hosted-zones.json`
- `tmp/route53-resource-record-sets-<zone-id>.json`

`tmp/` is gitignored.

## 2. Create the Terraform state bucket

With target-account credentials loaded, and `TF_STATE_BUCKET` set to a globally unique bucket name:

```bash
make terraform-bootstrap-state-bucket
```

The script creates the bucket when it is missing, then enables versioning, AES256 encryption, a full public-access block, and bucket-owner-enforced ownership. Running it again reapplies those settings.

Initialize Terraform against that bucket. State is stored at `portfolio-platform/terraform.tfstate`, encrypted, with native S3 locking. The DNS stack lives in `layers/01-foundation/terraform/dns-zone` (`STACK` in the makefile):

```bash
make terraform-dns-zone-init
```

## 3. Provision the hosted zone in the target account

Terraform in `layers/01-foundation/terraform/dns-zone/` creates the public hosted zone (`paulserban.eu` by default) and the SEO and ownership records taken from the export:

- Google site-verification TXT
- DMARC TXT
- Bing site-verification CNAMEs
- ACM DNS-validation CNAMEs

Apex NS and SOA records are created by the hosted zone itself. CloudFront alias records are not in this configuration.

```bash
make terraform-dns-zone-plan
make terraform-dns-zone-apply
```

After apply:

```bash
make terraform-dns-zone-output
```

`name_servers` is the delegation target for the new zone. Updating the domain registrar is a separate step and is not done by this Terraform.

## 4. Destroy the hosted zone in the target account

```bash
make terraform-dns-zone-destroy
```