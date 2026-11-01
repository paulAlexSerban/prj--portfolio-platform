---
name: Terraform S3 State Backend
overview: Configure the Terraform root in infrastructure/provisioning/terraform to store state in an S3 bucket (native S3 locking, partial backend config from .env), add a bootstrap script that creates the bucket, and revert main.tf to a plain real-AWS provider.
todos:
  - id: revert-main
    content: Revert main.tf to plain provider "aws" {}
    status: completed
  - id: backend-block
    content: Add partial s3 backend block and bump required_version to >= 1.10.0 in versions.tf
    status: completed
  - id: env-example
    content: Add TF_STATE_BUCKET to .env.example
    status: completed
  - id: bootstrap-script
    content: Create bootstrap-terraform-state-bucket.bash script
    status: completed
  - id: makefile-targets
    content: Add makefile targets for bootstrap and terraform-init
    status: completed
  - id: validate
    content: Run terraform fmt and validate
    status: completed
isProject: false
---

## Current state
- [infrastructure/provisioning/terraform/versions.tf](infrastructure/provisioning/terraform/versions.tf): `required_version >= 1.5.0`, aws provider `~> 5.70`.
- [infrastructure/provisioning/terraform/main.tf](infrastructure/provisioning/terraform/main.tf): LocalStack-style provider referencing `var.aws_endpoint`, which is **not defined** in `variables.tf` (config currently broken).
- Installed Terraform is v1.16.5, so native S3 locking is available.

## Decisions (confirmed)
- Bucket created by an aws-cli bootstrap script; Terraform only references it.
- Locking via `use_lockfile = true` (no DynamoDB); needs Terraform >= 1.10.
- Partial backend config: values come from `.env`, not hardcoded.
- Revert `main.tf` to a plain real-AWS provider.

## Changes

1. [infrastructure/provisioning/terraform/main.tf](infrastructure/provisioning/terraform/main.tf)
   Revert to:
   ```hcl
   # Credentials and region come from AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION (.env).
   provider "aws" {}
   ```

2. [infrastructure/provisioning/terraform/versions.tf](infrastructure/provisioning/terraform/versions.tf)
   - Raise `required_version` to `>= 1.10.0`.
   - Add an empty partial backend:
   ```hcl
   backend "s3" {
     key          = "portfolio-platform/terraform.tfstate"
     encrypt      = true
     use_lockfile = true
   }
   ```
   `bucket` and `region` are supplied at init time.

3. [.env.example](.env.example)
   Add `TF_STATE_BUCKET=xxx` (region reuses `AWS_REGION`).

4. New `scripts/one-time/bootstrap-terraform-state-bucket.bash` (follows style of [scripts/one-time/export-route53-dns-zone-config.bash](scripts/one-time/export-route53-dns-zone-config.bash): `set -euo pipefail`, requires `TF_STATE_BUCKET` and `AWS_REGION`). Idempotently:
   - `aws s3api create-bucket` (with `LocationConstraint` unless `us-east-1`)
   - enable versioning
   - enable default SSE (AES256)
   - block all public access
   - optional bucket-owner-enforced ownership

5. [makefile](makefile)
   Add targets:
   - `terraform-bootstrap-state-bucket` -> runs the bootstrap script
   - `terraform-init` -> `terraform -chdir=infrastructure/provisioning/terraform init -backend-config="bucket=$$TF_STATE_BUCKET" -backend-config="region=$$AWS_REGION"`

6. [_docs/00--ideas/01 migrate domain between aws accounts.md](_docs/00--ideas/01%20migrate%20domain%20between%20aws%20accounts.md)
   Not changed. `.gitignore` already ignores `.terraform/` and tfstate files.

## Workflow after implementation
```bash
set -a && source .env && set +a
make terraform-bootstrap-state-bucket
make terraform-init
terraform -chdir=infrastructure/provisioning/terraform plan
```
Existing local `.terraform/` was initialised with `-backend=false`, so `init` will configure the backend fresh (no state to migrate).

## Verification
- `terraform fmt -check` and `terraform validate` (after `init -backend=false`).
- Real backend init requires valid AWS credentials and the bucket, so it is left for the user to run.
