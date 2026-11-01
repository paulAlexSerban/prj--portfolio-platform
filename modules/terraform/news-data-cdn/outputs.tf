output "bucket_name" {
  description = "Name of the S3 bucket holding news JSON."
  value       = aws_s3_bucket.data.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket holding news JSON."
  value       = aws_s3_bucket.data.arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID. Needed by CI to invalidate after a news-sync push."
  value       = aws_cloudfront_distribution.data.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN. Used to scope the news-sync role's CreateInvalidation permission."
  value       = aws_cloudfront_distribution.data.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront-assigned domain name (*.cloudfront.net)."
  value       = aws_cloudfront_distribution.data.domain_name
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate. It may still be pending validation when enable_custom_domain is false."
  value       = aws_acm_certificate.data.arn
}

output "news_data_url" {
  description = "Public HTTPS base URL for news JSON (PUBLIC_NEWS_DATA_URL in the news-feed site)."
  value       = "https://${var.domain_name}"
}
