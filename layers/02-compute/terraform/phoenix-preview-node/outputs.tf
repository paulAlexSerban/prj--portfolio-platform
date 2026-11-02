output "aws_region" {
  description = "Region the instance, ECR repository, bucket, and parameters live in."
  value       = var.aws_region
}

output "instance_id" {
  description = "EC2 instance ID. make deploy-staging targets this with SSM."
  value       = module.node.instance_id
}

output "public_ip" {
  description = "Elastic IP of the preview node. Port 80 on this address answers only to CloudFront."
  value       = module.node.public_ip
}

output "origin_fqdn" {
  description = "Pretty origin hostname in this account's zone. It resolves only after paulserban.eu is delegated here."
  value       = trimsuffix(aws_route53_record.origin.fqdn, ".")
}

output "origin_connect_hostname" {
  description = "Public DNS name of the Elastic IP. CloudFront uses this as the origin so the connection works before the zone is delegated."
  value       = "ec2-${replace(module.node.public_ip, ".", "-")}.${var.aws_region}.compute.amazonaws.com"
}

output "staging_hostname" {
  description = "Public hostname the workload stack attaches to CloudFront."
  value       = local.staging_hostname
}

output "ecr_repository_url" {
  description = "Registry URL the WordPress image is pushed to. Tags are the git sha and staging."
  value       = aws_ecr_repository.wordpress.repository_url
}

output "release_bucket" {
  description = "Private bucket for the compose bundle, the database seed, and nightly dumps."
  value       = aws_s3_bucket.release.bucket
}

output "ssm_prefix" {
  description = "Parameter Store path the node reads at deploy time."
  value       = local.ssm_prefix
}

output "basic_auth_user" {
  description = "Basic Auth username for wp-admin. The password is the basic_auth_password output."
  value       = var.basic_auth_user
}

output "basic_auth_password" {
  description = "Basic Auth password for wp-admin. Read it with terraform output -raw basic_auth_password."
  value       = random_password.basic_auth.result
  sensitive   = true
}

output "cloudfront_prefix_list_max_entries" {
  description = "If apply failed with RulesPerSecurityGroupLimitExceeded, raise the VPC security group rules quota to at least this number."
  value       = module.node.cloudfront_prefix_list_max_entries
}
