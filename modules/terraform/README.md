# Terraform modules

Shared modules called by more than one layer. A stack in `layers/` instantiates these; it does not copy them.

Planned modules:

- `static-site`: private S3, Origin Access Control, CloudFront, ACM, Route 53 records, a security-headers policy, and an SPA toggle.
- `dns-zone`
- `ec2-k3s-node`
- `cloudfront-origin-ec2`
- `github-oidc-role`
- `budget-alerts`
