variable "aws_region" {
  description = "Region for the instance, ECR, S3, and SSM. This does not follow AWS_REGION from .env when that value is the state bucket region."
  type        = string
  default     = "eu-central-1"
}

variable "domain_name" {
  description = "Apex domain whose public hosted zone already exists in this account."
  type        = string
  default     = "paulserban.eu"
}

variable "client_slug" {
  description = "Client segment of the hostname. staging.<client_slug>.<domain> and origin-staging.<client_slug>.<domain>."
  type        = string
  default     = "phoenixartschool"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,40}$", var.client_slug))
    error_message = "client_slug must be 3 to 40 characters: lowercase letters, digits, and hyphens."
  }
}

variable "bucket_suffix" {
  description = "Short suffix that keeps the release bucket name globally unique. Use the same suffix as the static-sites stack."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{4,8}$", var.bucket_suffix))
    error_message = "bucket_suffix must be 4 to 8 lowercase letters or digits."
  }
}

variable "instance_type" {
  description = "EC2 instance type passed to the ec2-docker-host module."
  type        = string
  default     = "t4g.small"
}

variable "admin_allowed_ips" {
  description = "IPv4 or IPv6 addresses allowed to open /wp-admin and /wp-login.php. Empty locks wp-admin for everyone. Update with make staging-set-admin-ip from the WordPress repo, then keep this list in sync."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for ip in var.admin_allowed_ips :
      can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", ip)) || can(regex("^[0-9A-Fa-f:]+$", ip))
    ])
    error_message = "admin_allowed_ips entries must be IPv4 or IPv6 addresses, without a CIDR suffix."
  }
}

variable "basic_auth_user" {
  description = "Username for the extra Basic Auth prompt on wp-admin and wp-login.php."
  type        = string
  default     = "paul"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,32}$", var.basic_auth_user))
    error_message = "basic_auth_user must be 1 to 32 characters: letters, digits, dot, underscore, hyphen."
  }
}

variable "owner" {
  description = "Value of the owner tag."
  type        = string
  default     = "paul"
}
