# Cut over the personal portfolio to the new AWS account

The new account's zone for `paulserban.eu` is not delegated yet, and the old account's CloudFront distributions still own the hostnames. A distribution cannot take a hostname another distribution already has, and a certificate cannot be validated from a zone that is not delegated. This runbook builds the new stack first, proves it on the `*.cloudfront.net` URLs, issues the certificates through the old zone, then moves one hostname at a time.

Expect a few minutes of downtime per site, between removing the old alias and the new distribution accepting the hostname.

Terraform for the new account lives in this repo. The deploy workflows stay in `prj--personal-portfolio--v3` and read bucket names, distribution ids, and the role ARN from GitHub Environment variables.

## Before you start

- New-account credentials are in `.env`. `set -a && source .env && set +a`.
- The state bucket exists (`make terraform-bootstrap-state-bucket`) and the dns-zone stack has been applied. Do not change the registrar nameservers yet.
- You can reach the old account, either as `OLD_AWS_PROFILE` or as `OLD_AWS_ACCESS_KEY_ID` and `OLD_AWS_SECRET_ACCESS_KEY`.
- `gh` is authenticated for `paulAlexSerban/prj--personal-portfolio--v3`.
- At least 24 hours before step 4, lower the TTL of the site A and AAAA records in the old zone to 60 seconds.

`assets.paulserban.eu` is out of scope. The new zone gets an alias to the existing distribution (`d31dr77x3y18fg.cloudfront.net`). The content repo keeps writing the old bucket.

## 1. Build the stack with no custom domains

```bash
cp layers/05-workloads/terraform/static-sites/terraform.tfvars.example \
  layers/05-workloads/terraform/static-sites/terraform.tfvars
```

Set `bucket_suffix` to your own 4 to 8 character value. Leave every `custom_domain_enabled` entry false.

```bash
make terraform-oidc-init
make terraform-oidc-apply
make terraform-static-sites-init
make terraform-static-sites-apply
```

The first apply creates the buckets, the distributions on their `*.cloudfront.net` names, the ACM certificates (pending), the validation CNAMEs in the new zone, and the two deploy roles. It does not wait for the certificates to be issued.

Create the GitHub Environments `production`, `production-approval` (with required reviewers), and `news-data` if they are not there yet. Then:

```bash
make sync-github-env-vars
```

That sets `AWS_REGION`, `AWS_ACCOUNT_ID`, `AWS_DEPLOY_ROLE_ARN`, and the bucket and distribution variables. Once `AWS_ACCOUNT_ID` is set, the portfolio workflows refuse to deploy when the assumed account does not match it. Until then the check is skipped, so the current stage, test, and news-data deploys keep working.

## 2. Prove a deploy before any DNS change

Run **Deploy PRODUCTION** and **News Sync** in `prj--personal-portfolio--v3`.

Smoke-test the URLs from `terraform output preview_urls` in `layers/05-workloads/terraform/static-sites`. These are the `*.cloudfront.net` hostnames. The real domains still serve the old account.

## 3. Issue the certificates

The certificates already exist from step 1. Re-running the target is safe and creates nothing else:

```bash
make terraform-static-sites-certs
```

This target applies only the certificate and its validation records. It does not attach hostnames, and it does not wait. Waiting here would deadlock, because the new zone is not authoritative yet.

Copy the validation CNAMEs into the old zone and wait until ACM reports `ISSUED`:

```bash
OLD_AWS_PROFILE=<old-account-profile> \
  bash scripts/one-time/copy-acm-validation-to-old-zone.bash
```

The old zone id defaults to `Z0098660U3Z7GN6KH4L1`. Override it with `OLD_HOSTED_ZONE_ID` if that is wrong.

## 4. Move one site at a time

Order: blog, news-feed, quiz, news-data, then the apex (portfolio and www) last.

For each site:

1. In the **old** account, edit that CloudFront distribution and remove its alternate domain name. Wait until the distribution status is Deployed. Do not apply the old account's Terraform afterwards. It would put the alias back. Leave that stack untouched until decommission.
2. In `terraform.tfvars`, set that one key of `custom_domain_enabled` to `true` and apply:

   ```bash
   make terraform-static-sites-apply
   ```

   This attaches the hostname and the issued certificate, and writes the A and AAAA aliases in the **new** zone. The certificate waiter returns immediately because step 3 already issued it.

3. In the **old** zone, change that hostname's A and AAAA alias so they target the new distribution. The domain is `terraform output cloudfront_domain_names` for that site. The alias hosted zone id is `Z2FDTNDATAQYW2` for every CloudFront distribution. Resolvers still using the old nameservers then land on the new stack.
4. Open the real URL over HTTPS. Check the page, a deep link, and (for news-data) a JSON file.

While step 1 is done and step 3 is not, the hostname points at a distribution that no longer lists it, so CloudFront rejects the request. That is the downtime window.

## 5. Delegate the zone

When every site above responds from the new account, set the registrar nameservers to the `name_servers` output of the dns-zone stack (`make terraform-dns-zone-output` writes `.env.name_servers`).

Confirm with `dig` from more than one resolver. Watch the sites for a few days. The assets alias in the new zone already points at the old distribution, so `assets.paulserban.eu` keeps working after delegation.

## 6. Roll back

Before step 5: put the alternate domain back on the old distribution, restore the old zone's A and AAAA records, and set that site's `custom_domain_enabled` back to `false`.

After step 5: set the registrar nameservers back to the old zone. The old zone's records from step 4 already point at the new distributions, so fix those too if you want the old stack to serve traffic again.

## 7. Decommission, after a soak

- Destroy the old account's prod, stage, and test stacks, then delete the old hosted zone.
- Remove the copied ACM validation CNAMEs from the old zone. They disappear with the zone.
- Remove the leftover validation CNAMEs of the **old** certificates from this repo. They are the `acm_validation_*` entries in `layers/01-foundation/terraform/dns-zone/route53_records.tf` and the matching `TF_VAR_acm_validation_*` lines in `.env.example`. The new certificates' validation records are managed by the static-sites stack, not by that list.
- Delete `infrastructure/aws` from `prj--personal-portfolio--v3` once nothing in the old account is still managed from there.
