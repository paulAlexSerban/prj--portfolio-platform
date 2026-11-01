output "bucket_name" {
  description = "Name of the S3 bucket backing the site."
  value       = aws_s3_bucket.site.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket backing the site."
  value       = aws_s3_bucket.site.arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID. Needed by CI to invalidate the cache after a deploy."
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN. Used to scope the CI deploy role's CreateInvalidation permission."
  value       = aws_cloudfront_distribution.site.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront-assigned domain name (*.cloudfront.net)."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate. It may still be pending validation when enable_custom_domain is false."
  value       = aws_acm_certificate.site.arn
}

output "site_url" {
  description = "Public HTTPS URL for the site."
  value       = "https://${var.domain_name}"
}
