# Workloads

Owner: the consumer of each workload. Change cadence: frequent. Blast radius: low, limited to that consumer.

Deploy definitions for the things the platform runs: static sites, the WordPress preview, and later an API. Application source stays in product repositories.

- `terraform/static-sites/` for S3 and CloudFront sites.
- `gitops/apps/` for workloads Argo CD syncs, starting with the WordPress preview.
