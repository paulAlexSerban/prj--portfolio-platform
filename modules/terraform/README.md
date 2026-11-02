# Terraform modules

Shared modules called by more than one layer. A stack in `layers/` instantiates these; it does not copy them.

| Module | Used by | What it creates |
| --- | --- | --- |
| `static-site` | `layers/05-workloads/terraform/static-sites` | Private S3 bucket, Origin Access Control, CloudFront, ACM certificate, security headers, viewer-request function (directory index rewrite, optional basic auth and redirects), Route 53 alias records |
| `news-data-cdn` | same stack | Private S3 bucket and CloudFront distribution for the news JSON, with a short cache policy and open CORS |
| `assets-cdn` | same stack | Private S3 bucket and CloudFront distribution for `assets.<domain>`. CachingOptimized, real 404s, no HTML error pages. `content--paulserban.eu` writes the bucket |
| `github-oidc-role` | same stack | IAM role trusted by one GitHub repository environment. Looks up the account OIDC provider; it does not create one |
| `ec2-docker-host` | `layers/02-compute/terraform/phoenix-preview-node` | ARM Amazon Linux instance, Docker and the compose plugin, 1 GB swap, Elastic IP, SSM role, port 80 only from the CloudFront origin prefix list |
| `cloudfront-origin-ec2` | `layers/05-workloads/terraform/phoenixartschool-staging` | CloudFront in front of an HTTP origin, ACM certificate, noindex header, Route 53 alias records |

`enable_custom_domain` (default `true` on the static modules, `false` on `cloudfront-origin-ec2`) controls whether the distribution claims its hostname. When it is false the distribution uses the default `*.cloudfront.net` certificate and creates no alias records. The ACM certificate and its validation CNAMEs are still created, so they can be issued before the hostname is free.

Not built yet: `dns-zone` (the zone is a stack, not a module), `ec2-k3s-node`, `budget-alerts`.
