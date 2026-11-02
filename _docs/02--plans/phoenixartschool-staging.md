# Phoenix Art School staging

Preview of the WordPress site at `staging.phoenixartschool.paulserban.eu`. One `t4g.small` instance runs WordPress and MariaDB in Docker. CloudFront terminates TLS and is the only client allowed to connect. There is no SSH.

The image and the deploy scripts live in `prj--phoenixartschool`. This repo only provisions the node, the distribution, and the DNS records.

PHP 8.1 on the image is past upstream end of life. The tag matches the local dev stack. Upgrade both together; this preview does not move the version on its own.

## Cost

About 15 to 17 USD a month: `t4g.small` near 12 USD, 20 GB gp3 near 2 USD, and a dollar or two for Route 53, CloudFront, ECR, and the bucket. The Elastic IP is free while it is attached. Stopping the instance releases that saving only if the address is released too; a detached Elastic IP is billed.

## Before the first apply

Load this repo's `.env` (`set -a && source .env && set +a`). The dns-zone stack must already exist.

The security group references the CloudFront origin-facing prefix list. Every entry counts toward the inbound-rules quota, whose default is 60. Check the list size:

```bash
aws ec2 describe-managed-prefix-lists \
  --region eu-central-1 \
  --filters Name=prefix-list-name,Values=com.amazonaws.global.cloudfront.origin-facing \
  --query 'PrefixLists[0].MaxEntries'
```

If that number is above the quota, request a raise for "Inbound or outbound rules per security group" (`L-0EA8095F`) in eu-central-1 before apply. The compute stack prints `cloudfront_prefix_list_max_entries` after a successful apply. `RulesPerSecurityGroupLimitExceeded` means the quota is still too low.

## 1. Preview node

```bash
cp layers/02-compute/terraform/phoenix-preview-node/terraform.tfvars.example \
  layers/02-compute/terraform/phoenix-preview-node/terraform.tfvars
```

Set `bucket_suffix`. Leave `admin_allowed_ips` empty until the site is up; an empty list locks `/wp-admin` for everyone.

```bash
make terraform-phoenix-node-init
make terraform-phoenix-node-plan
make terraform-phoenix-node-apply
```

This creates the instance, the Elastic IP, the ECR repository, the private release bucket, the Parameter Store secrets, and `origin-staging.phoenixartschool.paulserban.eu`. CloudFront does not use that name to connect. It uses the instance public DNS (`origin_connect_hostname`), which resolves before `paulserban.eu` is delegated to this account. The pretty name is the same address once the zone is delegated.

First boot installs Docker, the compose plugin, and a 1 GB swap file, and enables a nightly backup timer. The timer no-ops until the first deploy. Changing user data replaces the instance and its disk. Dump the database to S3 first.

Basic Auth password:

```bash
terraform -chdir=layers/02-compute/terraform/phoenix-preview-node output -raw basic_auth_password
```

The username is `basic_auth_user` (default `paul`).

## 2. Deploy WordPress

From `prj--phoenixartschool`, with the same AWS credentials available and Docker running:

```bash
make deploy-staging
make staging-seed-db
```

The deploy scripts assume `client_slug` stays `phoenixartschool`. They read the compute stack outputs for the instance, the repository, and the bucket.

`deploy-staging` builds `linux/arm64`, pushes the git sha and a `staging` tag to ECR, and starts the containers over SSM.

`staging-seed-db` imports `database/backup/phoenixartschool.sql` and rewrites `local.phoenixartschool.ro` and `phoenixartschool.ro` to `https://staging.phoenixartschool.paulserban.eu`. It sets `blog_public` to 0. Running it again replaces the staging database.

The image bakes the theme, plugins, and uploads. `wp-google-maps` is downloaded at build time because it is gitignored and the dump expects it. `DISALLOW_FILE_MODS` is on, so plugins are not installed from wp-admin; change them in the image and redeploy.

## 3. CloudFront and the hostname

```bash
cp layers/05-workloads/terraform/phoenixartschool-staging/terraform.tfvars.example \
  layers/05-workloads/terraform/phoenixartschool-staging/terraform.tfvars
```

Set `tf_state_bucket` to `TF_STATE_BUCKET`. Leave `enable_custom_domain` false for the first apply.

```bash
make terraform-phoenix-staging-init
make terraform-phoenix-staging-plan
make terraform-phoenix-staging-apply
```

The distribution answers on the `preview_url` output (`*.cloudfront.net`) with the default certificate. WordPress still redirects to the staging hostname, so treat that URL as a TLS smoke test, not as the site.

The apply also writes the ACM validation CNAME into this account's zone. It does not wait for issuance while `enable_custom_domain` is false.

When `paulserban.eu` is delegated here, set `enable_custom_domain` to true and apply again. The apply waits until the certificate is issued, then attaches `staging.phoenixartschool.paulserban.eu` and the A and AAAA aliases.

When the zone is not delegated yet, copy `terraform output acm_validation_records` into the authoritative zone, wait until ACM shows `ISSUED`, then set `enable_custom_domain` to true and apply. Viewers still need the hostname to resolve. Add the alias in the authoritative zone as well, or delegate, before expecting the browser to open it. The alias target is `distribution_domain_name`. The CloudFront hosted zone id is `Z2FDTNDATAQYW2`.

## 4. Open wp-admin for yourself

```bash
make staging-set-admin-ip
```

With no arguments this uses your current IPv4 from `checkip.amazonaws.com`. Pass addresses when you need a specific one, including IPv6:

```bash
make staging-set-admin-ip IP='203.0.113.5 2001:db8::1'
```

The target writes the regex to Parameter Store, recreates the WordPress container, and updates `admin_allowed_ips` in the compute stack's `terraform.tfvars` when that file exists. Terraform is the source of truth: an apply with a stale tfvars puts the old list back.

If the distribution has IPv6 enabled and your browser connects over IPv6, the IPv4 entry will not match. Either pass the IPv6 address or set `is_ipv6_enabled = false` and apply the workload stack.

`/wp-admin` and `/wp-login.php` then require all three of: the CloudFront viewer address in the allowlist, the Basic Auth user and password, and the WordPress password. `/wp-admin/admin-ajax.php` stays open because the public pages use it. `xmlrpc.php` is denied. A second factor inside WordPress (an authenticator plugin) is worth adding on top of this; the image does not install one.

Direct requests to the Elastic IP on port 80 do not connect. Requests that reach Apache without the origin header are denied.

## Backups and restore

The timer runs `backup.sh` daily. Dumps land in `s3://<release bucket>/backups/` and expire after 14 days.

To restore, copy an object to the instance with SSM Session Manager (`aws ssm start-session --target <instance id>`) and import it as root into the `phoenixartschool` database, the same way `seed-db.sh` imports the seed. Skip the search-replace when the dump was taken from this staging site.

## Tear down

Empty the release bucket (versioning is on, so delete versions too), then `terraform destroy` the workload stack and then the compute stack. Destroying the compute stack deletes the instance, the disk, and the random passwords. The bucket's `backups/` prefix is the copy that survives the instance.

## What this preview does not do

Origin traffic from CloudFront to the instance is HTTP. The security group and the `X-Origin-Verify` header are what stop anyone else. A later step is a CloudFront VPC origin, or a certificate on Apache. The provider pin `~> 5.70` is older than the VPC-origin resource, so that step is a provider bump, not a flag.
