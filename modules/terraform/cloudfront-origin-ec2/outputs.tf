output "distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  description = "CloudFront-assigned domain name (*.cloudfront.net)."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate. It may still be pending validation when enable_custom_domain is false."
  value       = aws_acm_certificate.this.arn
}

output "acm_validation_records" {
  description = "DNS records that prove control of the hostname to ACM. Copy these into the authoritative zone when this account's zone is not delegated yet."
  value = {
    for name, record in aws_route53_record.cert_validation : name => {
      name   = record.name
      type   = record.type
      record = one(record.records)
    }
  }
}
