provider "aws" {
  region = var.aws_region
}

# CloudFront certificates must live in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

locals {
  domains = {
    portfolio = var.domain_name
    www       = "www.${var.domain_name}"
    blog      = "blog.${var.domain_name}"
    quiz      = "quiz.${var.domain_name}"
    news      = "news-feed.${var.domain_name}"
    news_data = "news-data.${var.domain_name}"
    assets    = "assets.${var.domain_name}"
  }

  # S3 names are global. The old account still holds <host>.paulserban.eu.
  buckets = {
    portfolio = "pserban-portfolio-prod-${var.bucket_suffix}"
    blog      = "pserban-blog-prod-${var.bucket_suffix}"
    quiz      = "pserban-quiz-prod-${var.bucket_suffix}"
    news      = "pserban-news-feed-prod-${var.bucket_suffix}"
    news_data = "pserban-news-data-prod-${var.bucket_suffix}"
    logs      = "pserban-cf-logs-prod-${var.bucket_suffix}"
  }

  # Same hosted zone id for every CloudFront distribution.
  cloudfront_hosted_zone_id = "Z2FDTNDATAQYW2"

  tags = {
    env         = "prod"
    owner       = var.owner
    cost-center = "portfolio"
  }
}

# ---------------------------------------------------------------------------
# Shared CloudFront access-log bucket.
# Standard logging still delivers with an ACL, which needs BucketOwnerPreferred
# rather than BucketOwnerEnforced.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "cf_access_logs" {
  bucket = local.buckets.logs
  tags   = merge(local.tags, { project = "portfolio" })
}

resource "aws_s3_bucket_public_access_block" "cf_access_logs" {
  bucket = aws_s3_bucket.cf_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "cf_access_logs" {
  bucket = aws_s3_bucket.cf_access_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cf_access_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.cf_access_logs]
  bucket     = aws_s3_bucket.cf_access_logs.id
  acl        = "log-delivery-write"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cf_access_logs" {
  bucket = aws_s3_bucket.cf_access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cf_access_logs" {
  bucket = aws_s3_bucket.cf_access_logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 60
    }
  }
}

module "static_site" {
  source = "../../../../modules/terraform/static-site"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  domain_name            = local.domains.portfolio
  alternate_domain_names = [local.domains.www]
  bucket_name            = local.buckets.portfolio
  hosted_zone_id         = data.aws_route53_zone.this.zone_id
  enable_custom_domain   = var.custom_domain_enabled["portfolio"]
  tags                   = merge(local.tags, { project = "portfolio" })

  access_logging_bucket = aws_s3_bucket.cf_access_logs.bucket_domain_name
  access_logging_prefix = "${local.domains.portfolio}/"

  # v2 blog lived under /blog on the apex. /assets redirects at the assets CDN
  # and keeps the path, so HTML deployed before the split still resolves.
  redirect_rules = [
    {
      path_prefix   = "/blog"
      target_domain = local.domains.blog
    },
    {
      path_prefix   = "/assets"
      target_domain = local.domains.assets
      strip_prefix  = false
    }
  ]
}

module "static_site_blog" {
  source = "../../../../modules/terraform/static-site"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  domain_name          = local.domains.blog
  bucket_name          = local.buckets.blog
  hosted_zone_id       = data.aws_route53_zone.this.zone_id
  enable_custom_domain = var.custom_domain_enabled["blog"]
  tags                 = merge(local.tags, { project = "blog" })

  access_logging_bucket = aws_s3_bucket.cf_access_logs.bucket_domain_name
  access_logging_prefix = "${local.domains.blog}/"
}

module "static_site_quiz" {
  source = "../../../../modules/terraform/static-site"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  domain_name          = local.domains.quiz
  bucket_name          = local.buckets.quiz
  hosted_zone_id       = data.aws_route53_zone.this.zone_id
  enable_custom_domain = var.custom_domain_enabled["quiz"]
  tags                 = merge(local.tags, { project = "quiz" })
  # Quiz is an SPA: map 403/404 to index.html with HTTP 200 so the client router runs.
  not_found_response_page = "/index.html"
  not_found_response_code = 200

  access_logging_bucket = aws_s3_bucket.cf_access_logs.bucket_domain_name
  access_logging_prefix = "${local.domains.quiz}/"
}

module "static_site_news" {
  source = "../../../../modules/terraform/static-site"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  domain_name          = local.domains.news
  bucket_name          = local.buckets.news
  hosted_zone_id       = data.aws_route53_zone.this.zone_id
  enable_custom_domain = var.custom_domain_enabled["news"]
  tags                 = merge(local.tags, { project = "news-feed" })

  access_logging_bucket = aws_s3_bucket.cf_access_logs.bucket_domain_name
  access_logging_prefix = "${local.domains.news}/"
}

module "news_data_cdn" {
  source = "../../../../modules/terraform/news-data-cdn"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  domain_name          = local.domains.news_data
  bucket_name          = local.buckets.news_data
  hosted_zone_id       = data.aws_route53_zone.this.zone_id
  enable_custom_domain = var.custom_domain_enabled["news_data"]
  tags                 = merge(local.tags, { project = "news-data" })

  access_logging_bucket = aws_s3_bucket.cf_access_logs.bucket_domain_name
  access_logging_prefix = "${local.domains.news_data}/"
}

# assets.paulserban.eu stays on the old account's distribution until that bucket
# moves. These records only matter once this zone is delegated.
resource "aws_route53_record" "assets_a" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.domains.assets
  type    = "A"

  alias {
    name                   = var.assets_cloudfront_domain_name
    zone_id                = local.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "assets_aaaa" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.domains.assets
  type    = "AAAA"

  alias {
    name                   = var.assets_cloudfront_domain_name
    zone_id                = local.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

module "github_oidc_deploy_role" {
  source = "../../../../modules/terraform/github-oidc-role"

  github_org         = var.github_org
  github_repo        = var.github_repo
  github_environment = "production"
  role_name          = "gha-deploy-${var.domain_name}"

  s3_bucket_arns = [
    module.static_site.bucket_arn,
    module.static_site_blog.bucket_arn,
    module.static_site_quiz.bucket_arn,
    module.static_site_news.bucket_arn,
  ]
  cloudfront_distribution_arns = [
    module.static_site.cloudfront_distribution_arn,
    module.static_site_blog.cloudfront_distribution_arn,
    module.static_site_quiz.cloudfront_distribution_arn,
    module.static_site_news.cloudfront_distribution_arn,
  ]

  tags = merge(local.tags, { project = "portfolio" })
}

# news-sync.yaml only. It cannot write the four site buckets.
module "github_oidc_news_sync_role" {
  source = "../../../../modules/terraform/github-oidc-role"

  github_org         = var.github_org
  github_repo        = var.github_repo
  github_environment = "news-data"
  role_name          = "gha-news-sync-${var.domain_name}"

  s3_bucket_arns = [
    module.news_data_cdn.bucket_arn,
  ]
  cloudfront_distribution_arns = [
    module.news_data_cdn.cloudfront_distribution_arn,
  ]

  tags = merge(local.tags, { project = "news-data" })
}
