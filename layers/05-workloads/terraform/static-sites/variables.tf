variable "aws_region" {
  description = "Region for the S3 buckets. CloudFront and ACM always use us-east-1. This does not follow AWS_REGION from .env, which is the state bucket region."
  type        = string
  default     = "eu-central-1"
}

variable "domain_name" {
  description = "Apex domain. Site hostnames are derived from it: the apex, www, blog, quiz, news-feed, news-data, and assets."
  type        = string
  default     = "paulserban.eu"
}

variable "bucket_suffix" {
  description = "Short suffix that keeps the S3 bucket names globally unique, for example 7f3a. Buckets are named pserban-<workload>-prod-<suffix> so they do not collide with the buckets still held by the old account."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{4,8}$", var.bucket_suffix))
    error_message = "bucket_suffix must be 4 to 8 lowercase letters or digits."
  }
}

variable "custom_domain_enabled" {
  description = "Per-site switch. False serves the site on its *.cloudfront.net hostname with the default certificate. True attaches the custom domain, the ACM certificate, and the Route 53 alias records in this account's zone. Flip one site at a time during cutover, after that hostname's alias is removed from the old account's distribution."
  type        = map(bool)
  default = {
    portfolio = false
    blog      = false
    quiz      = false
    news      = false
    news_data = false
    assets    = false
  }

  validation {
    condition     = sort(keys(var.custom_domain_enabled)) == sort(["assets", "blog", "news", "news_data", "portfolio", "quiz"])
    error_message = "custom_domain_enabled must contain exactly the keys portfolio, blog, quiz, news, news_data, and assets."
  }
}

variable "github_org" {
  description = "GitHub organization or user that owns the portfolio repository."
  type        = string
  default     = "paulAlexSerban"
}

variable "github_repo" {
  description = "GitHub repository name, without the owner prefix."
  type        = string
  default     = "prj--personal-portfolio--v3"
}

variable "owner" {
  description = "Value of the owner tag."
  type        = string
  default     = "paul"
}
