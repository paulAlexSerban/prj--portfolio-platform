output "instance_id" {
  description = "EC2 instance ID. Deploy scripts target this with SSM Run Command."
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Elastic IP attached to the instance."
  value       = aws_eip.this.public_ip
}

output "elastic_ip_allocation_id" {
  description = "Allocation ID of the Elastic IP."
  value       = aws_eip.this.id
}

output "security_group_id" {
  description = "Security group that admits port 80 from CloudFront only."
  value       = aws_security_group.this.id
}

output "role_name" {
  description = "Instance role name. The calling stack attaches workload permissions to it."
  value       = aws_iam_role.this.name
}

output "role_arn" {
  description = "Instance role ARN."
  value       = aws_iam_role.this.arn
}

output "subnet_id" {
  description = "Subnet the instance runs in."
  value       = local.subnet_id
}

output "vpc_id" {
  description = "VPC the security group belongs to."
  value       = local.vpc_id
}

output "cloudfront_prefix_list_id" {
  description = "Managed prefix list referenced by the HTTP ingress rule."
  value       = data.aws_ec2_managed_prefix_list.cloudfront_origin.id
}

output "cloudfront_prefix_list_max_entries" {
  description = "Upper bound of the CloudFront origin prefix list. The security group rules quota must be at least this large."
  value       = data.aws_ec2_managed_prefix_list.cloudfront_origin.max_entries
}
