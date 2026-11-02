data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

data "terraform_remote_state" "node" {
  backend = "s3"

  config = {
    bucket = var.tf_state_bucket
    key    = "02-compute/phoenix-preview-node/staging.tfstate"
    region = var.tf_state_region
  }
}

data "aws_ssm_parameter" "origin_verify" {
  name = "/${var.client_slug}/staging/origin_verify_secret"
}

locals {
  staging_hostname = "staging.${var.client_slug}.${var.domain_name}"

  tags = {
    project     = var.client_slug
    env         = "staging"
    owner       = var.owner
    cost-center = var.client_slug
  }
}

module "edge" {
  source = "../../../../modules/terraform/cloudfront-origin-ec2"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  # origin_connect_hostname is the ec2-x-x-x-x public name, so CloudFront can
  # resolve the instance before this account's zone is delegated.
  # origin-staging.<client>.<domain> still exists and points at the same address.
  name                       = "${var.client_slug}-staging"
  domain_name                = local.staging_hostname
  hosted_zone_id             = data.aws_route53_zone.this.zone_id
  origin_domain_name         = data.terraform_remote_state.node.outputs.origin_connect_hostname
  origin_verify_header_value = data.aws_ssm_parameter.origin_verify.value
  enable_custom_domain       = var.enable_custom_domain
  is_ipv6_enabled            = var.is_ipv6_enabled
  noindex                    = true
  tags                       = local.tags
}
