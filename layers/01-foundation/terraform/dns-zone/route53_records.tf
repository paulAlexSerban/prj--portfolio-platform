# SEO and ownership records migrated from the source zone export.
# CloudFront alias (A/AAAA) records, apex NS/SOA, and records are omitted.
# TXT values are left unquoted; the AWS provider adds the quotes Route 53 requires.
# Token and validation values come from TF_VAR_* in .env (see .env.example).
locals {
  dns_records = {
    google_site_verification = {
      name = "${var.domain_name}."
      type = "TXT"
      ttl  = 300
      records = [
        "google-site-verification=${var.google_site_verification_token}",
      ]
    }

    bing_verify_apex = {
      name = "${var.bing_site_verification_token}.${var.domain_name}."
      type = "CNAME"
      ttl  = 300
      records = [
        "verify.bing.com",
      ]
    }

    acm_validation_apex_412c69c3 = {
      name = "${var.acm_validation_apex_412c69c3_name}.${var.domain_name}."
      type = "CNAME"
      ttl  = 500
      records = [
        var.acm_validation_apex_412c69c3_target,
      ]
    }

    acm_validation_apex_a6b6bc87 = {
      name = "${var.acm_validation_apex_a6b6bc87_name}.${var.domain_name}."
      type = "CNAME"
      ttl  = 60
      records = [
        var.acm_validation_apex_a6b6bc87_target,
      ]
    }

    dmarc = {
      name = "_dmarc.${var.domain_name}."
      type = "TXT"
      ttl  = 300
      records = [
        var.dmarc_policy,
      ]
    }

    acm_validation_assets = {
      name = "${var.acm_validation_assets_name}.assets.${var.domain_name}."
      type = "CNAME"
      ttl  = 60
      records = [
        var.acm_validation_assets_target,
      ]
    }

    bing_verify_blog = {
      name = "${var.bing_site_verification_token}.blog.${var.domain_name}."
      type = "CNAME"
      ttl  = 300
      records = [
        "verify.bing.com",
      ]
    }

    acm_validation_blog = {
      name = "${var.acm_validation_blog_name}.blog.${var.domain_name}."
      type = "CNAME"
      ttl  = 60
      records = [
        var.acm_validation_blog_target,
      ]
    }

    acm_validation_news_data = {
      name = "${var.acm_validation_news_data_name}.news-data.${var.domain_name}."
      type = "CNAME"
      ttl  = 60
      records = [
        var.acm_validation_news_data_target,
      ]
    }

    bing_verify_news_feed = {
      name = "${var.bing_site_verification_token}.news-feed.${var.domain_name}."
      type = "CNAME"
      ttl  = 300
      records = [
        "verify.bing.com",
      ]
    }

    acm_validation_news_feed = {
      name = "${var.acm_validation_news_feed_name}.news-feed.${var.domain_name}."
      type = "CNAME"
      ttl  = 60
      records = [
        var.acm_validation_news_feed_target,
      ]
    }

    acm_validation_quiz = {
      name = "${var.acm_validation_quiz_name}.quiz.${var.domain_name}."
      type = "CNAME"
      ttl  = 60
      records = [
        var.acm_validation_quiz_target,
      ]
    }

    bing_verify_www = {
      name = "${var.bing_site_verification_token}.www.${var.domain_name}."
      type = "CNAME"
      ttl  = 300
      records = [
        "verify.bing.com",
      ]
    }

    acm_validation_www = {
      name = "${var.acm_validation_www_name}.www.${var.domain_name}."
      type = "CNAME"
      ttl  = 60
      records = [
        var.acm_validation_www_target,
      ]
    }
  }
}

resource "aws_route53_record" "dns" {
  for_each = local.dns_records

  zone_id = aws_route53_zone.this.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records
}
