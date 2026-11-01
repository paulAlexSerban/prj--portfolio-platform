output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider. Deploy roles look this up by URL."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}
