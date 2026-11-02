data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

# CloudFront publishes the addresses its origin fetches come from. Referencing
# the list costs one security-group rule per entry. The managed list is larger
# than the default 60-rule quota on many accounts, so apply fails with
# RulesPerSecurityGroupLimitExceeded until the VPC quota
# "Inbound or outbound rules per security group" is raised above the list's
# max_entries. This security group is dedicated to that one rule so the quota
# is not shared with anything else.
data "aws_ec2_managed_prefix_list" "cloudfront_origin" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

data "aws_vpc" "default" {
  count   = var.vpc_id == null ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.subnet_id == null ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

locals {
  vpc_id    = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id
  subnet_id = var.subnet_id != null ? var.subnet_id : sort(data.aws_subnets.default[0].ids)[0]
  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    extra_user_data = var.extra_user_data
  })
}

resource "aws_security_group" "this" {
  name        = var.name
  description = "HTTP from CloudFront origin-facing addresses only. No SSH."
  vpc_id      = local.vpc_id
  tags        = merge(var.tags, { Name = var.name })
}

resource "aws_vpc_security_group_ingress_rule" "http_from_cloudfront" {
  security_group_id = aws_security_group.this.id
  description       = "HTTP from CloudFront origin-facing prefix list"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_origin.id
  tags              = var.tags
}

resource "aws_vpc_security_group_egress_rule" "all_ipv4" {
  security_group_id = aws_security_group.this.id
  description       = "Outbound so the node can reach SSM, ECR, S3, and image registries"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags              = var.tags
}

resource "aws_vpc_security_group_egress_rule" "all_ipv6" {
  security_group_id = aws_security_group.this.id
  description       = "Outbound IPv6 for the same path as IPv4"
  ip_protocol       = "-1"
  cidr_ipv6         = "::/0"
  tags              = var.tags
}

resource "aws_iam_role" "this" {
  name = var.name
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  name = var.name
  role = aws_iam_role.this.name
  tags = var.tags
}

resource "aws_instance" "this" {
  ami           = data.aws_ssm_parameter.al2023_arm64.value
  instance_type = var.instance_type
  subnet_id     = local.subnet_id

  vpc_security_group_ids = [aws_security_group.this.id]
  iam_instance_profile   = aws_iam_instance_profile.this.name

  # A public address is required for CloudFront (public origin) and for the
  # instance to reach SSM, ECR, and S3 without VPC endpoints. The security
  # group still admits port 80 only from CloudFront. There is no port 22.
  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size_gb
    encrypted   = true
  }

  user_data = local.user_data
  tags      = merge(var.tags, { Name = var.name })

  depends_on = [aws_iam_role_policy_attachment.ssm]
}

resource "aws_eip" "this" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = var.name })
}

resource "aws_eip_association" "this" {
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this.id
}
