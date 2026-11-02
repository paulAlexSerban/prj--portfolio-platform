locals {
  origin_id = "ec2-${var.name}"
  # Managed CachingDisabled. Dynamic WordPress HTML is not cached.
  caching_disabled_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  # Forwards every viewer header (including Host), every cookie, every query
  # string, and the CloudFront-Viewer-* headers. CloudFront-Viewer-Address is
  # what the origin uses for the wp-admin IP check. The custom origin header
  # is added by CloudFront itself and replaces any viewer-supplied value.
  all_viewer_and_cloudfront_headers_policy_id = "33f36d7e-f396-46d9-90e0-52428a34d9dc"

  # Ordered behaviors are first-match. Uncached paths are listed first.
  behaviors = concat(
    [for path in var.uncached_path_patterns : { path = path, cached = false }],
    [for path in var.cached_path_patterns : { path = path, cached = true }],
  )
}

resource "aws_acm_certificate" "this" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"
  tags              = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
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

# Created only once the hostname is attached, so an apply with the domain off
# does not wait on a zone that is not delegated yet.
resource "aws_acm_certificate_validation" "this" {
  count = var.enable_custom_domain ? 1 : 0

  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_cloudfront_cache_policy" "static" {
  name    = "${var.name}-static"
  comment = "Cache ${var.domain_name} static assets, including the ?ver query string WordPress appends."

  min_ttl     = 0
  default_ttl = 86400
  max_ttl     = 31536000

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "all"
    }

    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

resource "aws_cloudfront_response_headers_policy" "this" {
  name    = "${var.name}-headers"
  comment = "Security headers for ${var.domain_name}."

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

  dynamic "custom_headers_config" {
    for_each = var.noindex ? [1] : []
    content {
      items {
        header   = "X-Robots-Tag"
        value    = "noindex, nofollow"
        override = true
      }
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = var.is_ipv6_enabled
  aliases         = var.enable_custom_domain ? [var.domain_name] : []
  price_class     = var.price_class
  comment         = "EC2 origin for ${var.domain_name}"
  tags            = var.tags

  origin {
    domain_name = var.origin_domain_name
    origin_id   = local.origin_id

    custom_header {
      name  = var.origin_verify_header_name
      value = var.origin_verify_header_value
    }

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 60
      origin_keepalive_timeout = 5
    }
  }

  default_cache_behavior {
    target_origin_id           = local.origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = local.caching_disabled_policy_id
    origin_request_policy_id   = local.all_viewer_and_cloudfront_headers_policy_id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id
  }

  dynamic "ordered_cache_behavior" {
    for_each = { for index, behavior in local.behaviors : format("%02d", index) => behavior }
    content {
      path_pattern               = ordered_cache_behavior.value.path
      target_origin_id           = local.origin_id
      viewer_protocol_policy     = "redirect-to-https"
      allowed_methods            = ordered_cache_behavior.value.cached ? ["GET", "HEAD", "OPTIONS"] : ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods             = ["GET", "HEAD"]
      compress                   = true
      cache_policy_id            = ordered_cache_behavior.value.cached ? aws_cloudfront_cache_policy.static.id : local.caching_disabled_policy_id
      origin_request_policy_id   = local.all_viewer_and_cloudfront_headers_policy_id
      response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  dynamic "viewer_certificate" {
    for_each = var.enable_custom_domain ? [1] : []
    content {
      acm_certificate_arn      = aws_acm_certificate_validation.this[0].certificate_arn
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

resource "aws_route53_record" "a" {
  count = var.enable_custom_domain ? 1 : 0

  zone_id         = var.hosted_zone_id
  name            = var.domain_name
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa" {
  count = var.enable_custom_domain ? 1 : 0

  zone_id         = var.hosted_zone_id
  name            = var.domain_name
  type            = "AAAA"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
