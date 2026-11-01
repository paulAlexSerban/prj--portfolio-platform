terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.70"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

locals {
  bucket_name = coalesce(var.bucket_name, var.domain_name)
  # CloudFront resource names allow only alphanumerics, dashes, and underscores.
  cloudfront_name_prefix = replace(local.bucket_name, ".", "-")
  aliases                = concat([var.domain_name], var.alternate_domain_names)

  # Empty string when auth is off - do not use null + coalesce(..., "") because
  # Terraform's coalesce also rejects empty strings.
  basic_auth_header_value = (
    var.basic_auth_enabled
    ? "Basic ${base64encode("${var.basic_auth_username}:${var.basic_auth_password}")}"
    : ""
  )
}

check "basic_auth_credentials" {
  assert {
    condition = (
      !var.basic_auth_enabled ||
      (
        var.basic_auth_username != null &&
        var.basic_auth_username != "" &&
        var.basic_auth_password != null &&
        var.basic_auth_password != ""
      )
    )
    error_message = "basic_auth_username and basic_auth_password are required when basic_auth_enabled is true."
  }
}

# ---------------------------------------------------------------------------
# S3 bucket (private; only readable by CloudFront via Origin Access Control)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ---------------------------------------------------------------------------
# ACM certificate (must live in us-east-1 for CloudFront), DNS-validated
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "site" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = var.alternate_domain_names
  validation_method         = "DNS"
  tags                      = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# The waiter is created only once the custom domain is attached. Until then the
# certificate can sit in PENDING_VALIDATION while its CNAMEs are copied into
# the still-authoritative zone. A full apply with the domain off does not block.
resource "aws_acm_certificate_validation" "site" {
  count = var.enable_custom_domain ? 1 : 0

  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ---------------------------------------------------------------------------
# CloudFront distribution (Origin Access Control -> private S3 bucket)
# ---------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${local.cloudfront_name_prefix}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "site" {
  name    = "${local.cloudfront_name_prefix}-security-headers"
  comment = "HSTS, X-Content-Type-Options, Referrer-Policy for ${var.domain_name}"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
}

# Single viewer-request function: optional Basic Auth + directory -> index.html
# rewrite. CloudFront allows only one function association per event type, and
# default_root_object only applies to "/", so Astro's trailingSlash:"always"
# output (post/slug/index.html) needs an explicit rewrite for deep links.
#
# moved + create_before_destroy: rename from basic_auth[0] without deleting the
# old function while a distribution still references it (CloudFront 409
# FunctionInUse). Envs that already completed the migration ignore `moved`.
moved {
  from = aws_cloudfront_function.basic_auth[0]
  to   = aws_cloudfront_function.viewer_request
}

resource "aws_cloudfront_function" "viewer_request" {
  name    = "${local.cloudfront_name_prefix}-viewer-request"
  runtime = "cloudfront-js-2.0"
  publish = true
  code = templatefile("${path.module}/src/viewer-request.js.tftpl", {
    basic_auth_enabled = var.basic_auth_enabled
    auth_header_value  = local.basic_auth_header_value
    realm              = var.domain_name
    redirect_rules     = var.redirect_rules
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.default_root_object
  aliases             = var.enable_custom_domain ? local.aliases : []
  price_class         = var.price_class
  tags                = var.tags

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-${local.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "s3-${local.bucket_name}"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6" # AWS managed: CachingOptimized
    response_headers_policy_id = aws_cloudfront_response_headers_policy.site.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.viewer_request.arn
    }
  }

  dynamic "logging_config" {
    for_each = var.access_logging_bucket != null ? [1] : []
    content {
      include_cookies = false
      bucket          = var.access_logging_bucket
      prefix          = coalesce(var.access_logging_prefix, "${var.domain_name}/")
    }
  }

  # Missing objects: S3+OAC typically returns 403; a missing key can also be 404.
  # Static sites return a real 404 with the custom page body so crawlers see a
  # hard 404 instead of a soft-200. Quiz SPA overrides the response code to 200.
  custom_error_response {
    error_code            = 403
    response_code         = var.not_found_response_code
    response_page_path    = var.not_found_response_page
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = var.not_found_response_code
    response_page_path    = var.not_found_response_page
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  dynamic "viewer_certificate" {
    for_each = var.enable_custom_domain ? [1] : []
    content {
      acm_certificate_arn      = aws_acm_certificate_validation.site[0].certificate_arn
      ssl_support_method       = "sni-only"
      minimum_protocol_version = var.minimum_protocol_version
    }
  }

  dynamic "viewer_certificate" {
    for_each = var.enable_custom_domain ? [] : [1]
    content {
      cloudfront_default_certificate = true
    }
  }
}

data "aws_iam_policy_document" "site_bucket_policy" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.site.arn,
      "${aws_s3_bucket.site.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site_bucket_policy.json
}

# ---------------------------------------------------------------------------
# Route 53 alias records -> CloudFront
# ---------------------------------------------------------------------------

resource "aws_route53_record" "site_a" {
  count = var.enable_custom_domain ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "site_aaaa" {
  count = var.enable_custom_domain ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alternate_a" {
  for_each = var.enable_custom_domain ? toset(var.alternate_domain_names) : toset([])

  zone_id         = var.hosted_zone_id
  name            = each.value
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alternate_aaaa" {
  for_each = var.enable_custom_domain ? toset(var.alternate_domain_names) : toset([])

  zone_id         = var.hosted_zone_id
  name            = each.value
  type            = "AAAA"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
