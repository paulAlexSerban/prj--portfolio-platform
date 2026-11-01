# Credentials come from AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION (.env).
# IAM is global. Apply this stack before layers/05-workloads/terraform/static-sites:
# only one OIDC provider for token.actions.githubusercontent.com can exist per account,
# and the deploy roles look it up instead of creating it.
provider "aws" {}

locals {
  github_oidc_url = "https://token.actions.githubusercontent.com"

  tags = {
    project     = "platform"
    env         = "prod"
    owner       = "paul"
    cost-center = "platform"
  }
}

data "tls_certificate" "github_actions" {
  url = local.github_oidc_url
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = local.github_oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]

  tags = local.tags
}
