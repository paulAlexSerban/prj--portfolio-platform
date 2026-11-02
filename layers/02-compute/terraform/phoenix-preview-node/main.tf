data "aws_caller_identity" "current" {}

data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

locals {
  name             = "${var.client_slug}-staging"
  ssm_prefix       = "/${var.client_slug}/staging"
  staging_hostname = "staging.${var.client_slug}.${var.domain_name}"
  origin_fqdn      = "origin-staging.${var.client_slug}.${var.domain_name}"
  bucket_name      = "pserban-${var.client_slug}-staging-${var.bucket_suffix}"

  # Same shape the staging-set-admin-ip script writes. IPv4 is matched as
  # "addr:" and IPv6 as "[addr]:", which is how CloudFront-Viewer-Address
  # looks (address plus the viewer port). "^a^" matches nothing and contains
  # no "$", so an env-file loader cannot eat the anchor.
  admin_ip_alternatives = [
    for ip in var.admin_allowed_ips :
    strcontains(ip, ":") ? format("\\[%s\\]:", ip) : format("%s:", replace(ip, ".", "\\."))
  ]
  admin_ip_regex = length(local.admin_ip_alternatives) == 0 ? "^a^" : format("^(%s)", join("|", local.admin_ip_alternatives))

  wp_salts = toset([
    "auth_key",
    "secure_auth_key",
    "logged_in_key",
    "nonce_key",
    "auth_salt",
    "secure_auth_salt",
    "logged_in_salt",
    "nonce_salt",
  ])

  tags = {
    project     = var.client_slug
    env         = "staging"
    owner       = var.owner
    cost-center = var.client_slug
  }
}

resource "random_password" "db_root" {
  length  = 32
  special = false
}

resource "random_password" "db_user" {
  length  = 32
  special = false
}

resource "random_password" "origin_verify" {
  length  = 48
  special = false
}

resource "random_password" "basic_auth" {
  length  = 24
  special = false
}

resource "random_password" "wp_salt" {
  for_each = local.wp_salts
  length   = 64
  special  = false
}

resource "aws_ssm_parameter" "db_root_password" {
  name  = "${local.ssm_prefix}/db_root_password"
  type  = "SecureString"
  value = random_password.db_root.result
  tags  = local.tags
}

resource "aws_ssm_parameter" "db_password" {
  name  = "${local.ssm_prefix}/db_password"
  type  = "SecureString"
  value = random_password.db_user.result
  tags  = local.tags
}

resource "aws_ssm_parameter" "db_user" {
  name  = "${local.ssm_prefix}/db_user"
  type  = "String"
  value = "wordpress"
  tags  = local.tags
}

resource "aws_ssm_parameter" "db_name" {
  name  = "${local.ssm_prefix}/db_name"
  type  = "String"
  value = var.client_slug
  tags  = local.tags
}

resource "aws_ssm_parameter" "wp_table_prefix" {
  name  = "${local.ssm_prefix}/wp_table_prefix"
  type  = "String"
  value = "pas_"
  tags  = local.tags
}

resource "aws_ssm_parameter" "origin_verify_secret" {
  name  = "${local.ssm_prefix}/origin_verify_secret"
  type  = "SecureString"
  value = random_password.origin_verify.result
  tags  = local.tags
}

resource "aws_ssm_parameter" "basic_auth_user" {
  name  = "${local.ssm_prefix}/basic_auth_user"
  type  = "String"
  value = var.basic_auth_user
  tags  = local.tags
}

resource "aws_ssm_parameter" "basic_auth_password" {
  name  = "${local.ssm_prefix}/basic_auth_password"
  type  = "SecureString"
  value = random_password.basic_auth.result
  tags  = local.tags
}

resource "aws_ssm_parameter" "admin_ip_regex" {
  name  = "${local.ssm_prefix}/admin_ip_regex"
  type  = "String"
  value = local.admin_ip_regex
  tags  = local.tags
}

resource "aws_ssm_parameter" "wp_home" {
  name  = "${local.ssm_prefix}/wp_home"
  type  = "String"
  value = "https://${local.staging_hostname}"
  tags  = local.tags
}

resource "aws_ssm_parameter" "wp_salt" {
  for_each = local.wp_salts
  name     = "${local.ssm_prefix}/${each.key}"
  type     = "SecureString"
  value    = random_password.wp_salt[each.key].result
  tags     = local.tags
}

resource "aws_ecr_repository" "wordpress" {
  name                 = local.name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "wordpress" {
  repository = aws_ecr_repository.wordpress.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_s3_bucket" "release" {
  bucket = local.bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_public_access_block" "release" {
  bucket = aws_s3_bucket.release.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "release" {
  bucket = aws_s3_bucket.release.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "release" {
  bucket = aws_s3_bucket.release.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "release" {
  bucket = aws_s3_bucket.release.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "release" {
  bucket = aws_s3_bucket.release.id

  rule {
    id     = "expire-backups"
    status = "Enabled"

    filter {
      prefix = "backups/"
    }

    expiration {
      days = 14
    }

    noncurrent_version_expiration {
      noncurrent_days = 14
    }
  }

  rule {
    id     = "abort-multipart"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "release_bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.release.arn,
      "${aws_s3_bucket.release.arn}/*",
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

resource "aws_s3_bucket_policy" "release" {
  bucket = aws_s3_bucket.release.id
  policy = data.aws_iam_policy_document.release_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.release]
}

module "node" {
  source = "../../../../modules/terraform/ec2-docker-host"

  name          = local.name
  instance_type = var.instance_type
  tags          = local.tags

  extra_user_data = templatefile("${path.module}/user-data-extra.sh.tftpl", {
    client_slug = var.client_slug
    bucket      = aws_s3_bucket.release.bucket
    aws_region  = var.aws_region
  })
}

data "aws_iam_policy_document" "node" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = [aws_ecr_repository.wordpress.arn]
  }

  statement {
    sid       = "ListReleaseBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.release.arn]
  }

  statement {
    sid = "UseReleaseBucket"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.release.arn}/*"]
  }

  statement {
    sid = "ReadParameters"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_prefix}",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_prefix}/*",
    ]
  }
}

resource "aws_iam_role_policy" "node" {
  name   = "${local.name}-workload"
  role   = module.node.role_name
  policy = data.aws_iam_policy_document.node.json
}

resource "aws_route53_record" "origin" {
  zone_id         = data.aws_route53_zone.this.zone_id
  name            = local.origin_fqdn
  type            = "A"
  ttl             = 60
  records         = [module.node.public_ip]
  allow_overwrite = true
}
