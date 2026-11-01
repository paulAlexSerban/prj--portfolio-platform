# Workloads

Owner: the consumer of each workload. Change cadence: frequent. Blast radius: low, limited to that consumer.

Deploy definitions for the things the platform runs. Application source stays in the product repositories. GitHub Actions in those repos assume a role created here and sync build output to S3.

## Static sites

`terraform/static-sites/` hosts the personal portfolio in this account:

- `paulserban.eu` and `www.paulserban.eu` (portfolio, with redirects from `/blog` and `/assets`)
- `blog.paulserban.eu`
- `quiz.paulserban.eu` (SPA fallback)
- `news-feed.paulserban.eu`
- `news-data.paulserban.eu` (RSS JSON)
- `assets.paulserban.eu` (private bucket, filled by `content--paulserban.eu`)

State key is `05-workloads/static-sites/prod.tfstate`. Modules come from `modules/terraform/`. The hosted zone is looked up by name, so the dns-zone stack has to exist first, and the OIDC provider stack has to exist before the roles can be created.

Buckets are named `pserban-<workload>-prod-<suffix>`. The suffix is required because the old account still holds the domain-named buckets.

`custom_domain_enabled` defaults to false for every site. A site is then served on its `*.cloudfront.net` hostname. Turn one site on at a time, following [`_docs/02--plans/portfolio-cutover.md`](../../_docs/02--plans/portfolio-cutover.md).

```bash
cp layers/05-workloads/terraform/static-sites/terraform.tfvars.example \
  layers/05-workloads/terraform/static-sites/terraform.tfvars
make terraform-static-sites-init
make terraform-static-sites-plan
```
