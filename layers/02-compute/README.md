# Compute

Owner: platform. Change cadence: occasional. Blast radius: high.

Terraform creates machines. Configuration of a machine stays out of this layer's Terraform, apart from the first-boot user data that installs Docker.

## Phoenix Art School preview

`terraform/phoenix-preview-node/` is one `t4g.small` ARM instance running Docker. It is the origin for `staging.phoenixartschool.paulserban.eu`. State key is `02-compute/phoenix-preview-node/staging.tfstate`.

The security group has no SSH. Port 80 accepts the CloudFront origin-facing prefix list only. Administration is SSM Session Manager and Run Command. The instance role can pull from the stack's ECR repository, read its Parameter Store path, and read and write the release bucket.

Secrets (database passwords, WordPress salts, the CloudFront origin header, Basic Auth) are random and stored as SecureString parameters under `/phoenixartschool/staging`. Nothing secret is written to git.

Apply order and the wp-admin allowlist are in [`_docs/02--plans/phoenixartschool-staging.md`](../../_docs/02--plans/phoenixartschool-staging.md).

```bash
cp layers/02-compute/terraform/phoenix-preview-node/terraform.tfvars.example \
  layers/02-compute/terraform/phoenix-preview-node/terraform.tfvars
make terraform-phoenix-node-init
make terraform-phoenix-node-plan
```

## Later

The k3s node is not built. When it is, Terraform will live in `terraform/ec2-k3s-node` and Ansible (base hardening, k3s, backups, node exporter) in `ansible/`.
