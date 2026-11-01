# Terraform modules

Shared modules called by more than one layer. A stack in `layers/` instantiates these; it does not copy them.

| Module | Used by | What it creates |
| --- | --- | --- |
| `static-site` | `layers/05-workloads/terraform/static-sites` | Private S3 bucket, Origin Access Control, CloudFront, ACM certificate, security headers, viewer-request function (directory index rewrite, optional basic auth and redirects), Route 53 alias records |
| `news-data-cdn` | same stack | Private S3 bucket and CloudFront distribution for the news JSON, with a short cache policy and open CORS |
| `github-oidc-role` | same stack | IAM role trusted by one GitHub repository environment. Looks up the account OIDC provider; it does not create one |

`enable_custom_domain` (default `true`) controls whether the distribution claims its hostname. When it is false the distribution uses the default `*.cloudfront.net` certificate and creates no alias records. The ACM certificate and its validation CNAMEs are still created, so they can be issued before the hostname is free.

Not built yet: `dns-zone` (the zone is a stack, not a module), `ec2-k3s-node`, `cloudfront-origin-ec2`, `budget-alerts`. The assets CDN stays in the old account until that bucket moves.
