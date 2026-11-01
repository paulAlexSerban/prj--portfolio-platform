variable "github_org" {
  description = "GitHub organization or user that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix)."
  type        = string
}

variable "github_environment" {
  description = "GitHub Environment name that is allowed to assume this role (e.g. production)."
  type        = string
}

variable "role_name" {
  description = "Name of the IAM role GitHub Actions will assume."
  type        = string
}

variable "s3_bucket_arns" {
  description = "ARNs of the S3 buckets the role may sync into."
  type        = list(string)
}

variable "cloudfront_distribution_arns" {
  description = "ARNs of the CloudFront distributions the role may invalidate."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to IAM resources created by this module."
  type        = map(string)
  default     = {}
}
