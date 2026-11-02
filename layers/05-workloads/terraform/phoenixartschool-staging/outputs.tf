output "staging_hostname" {
  description = "Public hostname. Serves traffic only after enable_custom_domain is true and the certificate is issued."
  value       = local.staging_hostname
}

output "preview_url" {
  description = "HTTPS URL that works before the custom domain is attached."
  value       = "https://${module.edge.distribution_domain_name}"
}

output "distribution_id" {
  description = "CloudFront distribution ID."
  value       = module.edge.distribution_id
}

output "distribution_domain_name" {
  description = "CloudFront domain. Point an external zone's alias here if this account's zone is not authoritative yet."
  value       = module.edge.distribution_domain_name
}

output "acm_validation_records" {
  description = "Validation CNAMEs. They are written to this account's zone. Copy them to the old zone when this zone is not delegated."
  value       = module.edge.acm_validation_records
}
