output "bucket_name" {
  description = "Name of the S3 bucket holding content assets."
  value       = aws_s3_bucket.assets.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket holding content assets."
  value       = aws_s3_bucket.assets.arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.assets.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = aws_cloudfront_distribution.assets.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront-assigned domain name (*.cloudfront.net)."
  value       = aws_cloudfront_distribution.assets.domain_name
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate. It may still be pending validation when enable_custom_domain is false."
  value       = aws_acm_certificate.assets.arn
}

output "assets_url" {
  description = "Public HTTPS base for content assets."
  value       = "https://${var.domain_name}"
}
