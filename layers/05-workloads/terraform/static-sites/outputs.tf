output "aws_account_id" {
  description = "Account this stack applied into. Set as AWS_ACCOUNT_ID on the GitHub Environments so deploys refuse a stale role."
  value       = data.aws_caller_identity.current.account_id
}

output "hosted_zone_id" {
  description = "Route 53 zone the alias records are written to."
  value       = data.aws_route53_zone.this.zone_id
}

output "preview_urls" {
  description = "HTTPS URLs that work before the custom domains are attached. Use these to smoke-test a deploy."
  value = {
    portfolio = "https://${module.static_site.cloudfront_domain_name}"
    blog      = "https://${module.static_site_blog.cloudfront_domain_name}"
    quiz      = "https://${module.static_site_quiz.cloudfront_domain_name}"
    news      = "https://${module.static_site_news.cloudfront_domain_name}"
    news_data = "https://${module.news_data_cdn.cloudfront_domain_name}"
  }
}

output "cloudfront_domain_names" {
  description = "New distribution domains. During cutover, point the old zone's A/AAAA for each host at the matching domain."
  value = {
    portfolio = module.static_site.cloudfront_domain_name
    blog      = module.static_site_blog.cloudfront_domain_name
    quiz      = module.static_site_quiz.cloudfront_domain_name
    news      = module.static_site_news.cloudfront_domain_name
    news_data = module.news_data_cdn.cloudfront_domain_name
  }
}

output "github_actions_role_arn" {
  description = "IAM role for the production site deploys."
  value       = module.github_oidc_deploy_role.role_arn
}

output "github_actions_news_sync_role_arn" {
  description = "IAM role for news-sync.yaml."
  value       = module.github_oidc_news_sync_role.role_arn
}

output "github_environment_variables" {
  description = "Values for the production and news-data GitHub Environments. scripts/tools/sync-github-env-vars.bash writes these."
  value = {
    production = {
      AWS_REGION                           = var.aws_region
      AWS_ACCOUNT_ID                       = data.aws_caller_identity.current.account_id
      AWS_DEPLOY_ROLE_ARN                  = module.github_oidc_deploy_role.role_arn
      PORTFOLIO_S3_BUCKET_NAME             = module.static_site.bucket_name
      PORTFOLIO_CLOUDFRONT_DISTRIBUTION_ID = module.static_site.cloudfront_distribution_id
      BLOG_S3_BUCKET_NAME                  = module.static_site_blog.bucket_name
      BLOG_CLOUDFRONT_DISTRIBUTION_ID      = module.static_site_blog.cloudfront_distribution_id
      QUIZ_S3_BUCKET_NAME                  = module.static_site_quiz.bucket_name
      QUIZ_CLOUDFRONT_DISTRIBUTION_ID      = module.static_site_quiz.cloudfront_distribution_id
      NEWS_S3_BUCKET_NAME                  = module.static_site_news.bucket_name
      NEWS_CLOUDFRONT_DISTRIBUTION_ID      = module.static_site_news.cloudfront_distribution_id
    }
    "news-data" = {
      AWS_REGION                           = var.aws_region
      AWS_ACCOUNT_ID                       = data.aws_caller_identity.current.account_id
      AWS_DEPLOY_ROLE_ARN                  = module.github_oidc_news_sync_role.role_arn
      NEWS_DATA_S3_BUCKET_NAME             = module.news_data_cdn.bucket_name
      NEWS_DATA_CLOUDFRONT_DISTRIBUTION_ID = module.news_data_cdn.cloudfront_distribution_id
    }
  }
}
