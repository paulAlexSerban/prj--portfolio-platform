variable "aws_region" {
  description = "Region of the preview node and its SSM parameters. CloudFront and ACM use us-east-1 regardless."
  type        = string
  default     = "eu-central-1"
}

variable "domain_name" {
  description = "Apex domain whose public hosted zone already exists in this account."
  type        = string
  default     = "paulserban.eu"
}

variable "client_slug" {
  description = "Must match the compute stack. Hostname is staging.<client_slug>.<domain>."
  type        = string
  default     = "phoenixartschool"
}

variable "enable_custom_domain" {
  description = "Attach staging.<client>.<domain> to the distribution. Leave false until the certificate can validate, then set true. See the staging runbook."
  type        = bool
  default     = false
}

variable "is_ipv6_enabled" {
  description = "When true, viewers may be seen as IPv6. Include that address in admin_allowed_ips or set this false."
  type        = bool
  default     = true
}

variable "tf_state_bucket" {
  description = "Platform state bucket. Same value as TF_STATE_BUCKET. The compute stack's state is read from it."
  type        = string
}

variable "tf_state_region" {
  description = "Region of the state bucket. Same value as AWS_REGION in .env when that is the state bucket region."
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Value of the owner tag."
  type        = string
  default     = "paul"
}
