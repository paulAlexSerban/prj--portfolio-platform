# SEO and ownership records migrated from the source zone export.
# CloudFront alias (A/AAAA) records, apex NS/SOA, and Klaviyo records are omitted.
# TXT values keep the surrounding quotes required by the Route 53 API.
locals {
  dns_records = {
    google_site_verification = {
      name = "paulserban.eu."
      type = "TXT"
      ttl  = 300
      records = [
        "\"google-site-verification=5hGN5nx1FOuJPzNYbtrq8qZXTYayhWXisu26hoenfhw\"",
      ]
    }

    bing_verify_apex = {
      name = "2ec0a14cd64662ec65477e7a2a2751e4.paulserban.eu."
      type = "CNAME"
      ttl  = 300
      records = [
        "verify.bing.com",
      ]
    }

    acm_validation_apex_412c69c3 = {
      name = "_412c69c3af2c07a833fee7f551ebc93d.paulserban.eu."
      type = "CNAME"
      ttl  = 500
      records = [
        "_16e5e6647c5ad49ec3dde4121c693585.njdczhxdjc.acm-validations.aws.",
      ]
    }

    acm_validation_apex_a6b6bc87 = {
      name = "_a6b6bc878d7c046dfa693fbb8ce0d3a2.paulserban.eu."
      type = "CNAME"
      ttl  = 60
      records = [
        "_566b2ea84eae2be4f0e308794c3088b7.rvctyfnwhz.acm-validations.aws.",
      ]
    }

    dmarc = {
      name = "_dmarc.paulserban.eu."
      type = "TXT"
      ttl  = 300
      records = [
        "\"v=DMARC1; p=none\"",
      ]
    }

    acm_validation_assets = {
      name = "_b9bae35cacd94c0c2a8ec5b99bddde78.assets.paulserban.eu."
      type = "CNAME"
      ttl  = 60
      records = [
        "_7d8df691f9f70fdb900b5f20cd3b0718.mrhcxwpsky.acm-validations.aws.",
      ]
    }

    bing_verify_blog = {
      name = "2ec0a14cd64662ec65477e7a2a2751e4.blog.paulserban.eu."
      type = "CNAME"
      ttl  = 300
      records = [
        "verify.bing.com",
      ]
    }

    acm_validation_blog = {
      name = "_55a5abe32cde28891ae45489d05795de.blog.paulserban.eu."
      type = "CNAME"
      ttl  = 60
      records = [
        "_3418adb6f6ec0698a2a921e981d1d0d6.jkddzztszm.acm-validations.aws.",
      ]
    }

    acm_validation_news_data = {
      name = "_fbc53c1f8f9c81b05cb8ad6e0eeb6307.news-data.paulserban.eu."
      type = "CNAME"
      ttl  = 60
      records = [
        "_a82e9abfb769c5f2486e6b2d319411db.jkddzztszm.acm-validations.aws.",
      ]
    }

    bing_verify_news_feed = {
      name = "2ec0a14cd64662ec65477e7a2a2751e4.news-feed.paulserban.eu."
      type = "CNAME"
      ttl  = 300
      records = [
        "verify.bing.com",
      ]
    }

    acm_validation_news_feed = {
      name = "_aaf06c1f0e0623abff27fa062c80b222.news-feed.paulserban.eu."
      type = "CNAME"
      ttl  = 60
      records = [
        "_777b70ba1edec81fdf7ace0365754563.jkddzztszm.acm-validations.aws.",
      ]
    }

    acm_validation_quiz = {
      name = "_ce6acf433496b5ed9168b098ac4d5fb4.quiz.paulserban.eu."
      type = "CNAME"
      ttl  = 60
      records = [
        "_9843058162be3a032d5b39a5b8a561cd.jkddzztszm.acm-validations.aws.",
      ]
    }

    bing_verify_www = {
      name = "2ec0a14cd64662ec65477e7a2a2751e4.www.paulserban.eu."
      type = "CNAME"
      ttl  = 300
      records = [
        "verify.bing.com",
      ]
    }

    acm_validation_www = {
      name = "_0176293f2d56ed2426fbf34a5b289a69.www.paulserban.eu."
      type = "CNAME"
      ttl  = 60
      records = [
        "_3d52a716845341733c41227deed3f096.gnvqnzwrct.acm-validations.aws.",
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
