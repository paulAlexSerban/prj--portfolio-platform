variable "name" {
  description = "Short name for the distribution, cache policy, and response-headers policy. Lowercase letters, digits, and hyphens."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,40}$", var.name))
    error_message = "name must be 3 to 40 characters: lowercase letters, digits, and hyphens."
  }
}

variable "domain_name" {
  description = "Public hostname viewers use, for example staging.phoenixartschool.paulserban.eu."
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID that owns domain_name."
  type        = string
}

variable "origin_domain_name" {
  description = "DNS name CloudFront connects to. An A record for this name must point at the origin."
  type        = string
}

variable "origin_verify_header_name" {
  description = "Header CloudFront adds on every origin request. The origin rejects requests without it."
  type        = string
  default     = "X-Origin-Verify"
}

variable "origin_verify_header_value" {
  description = "Secret value of the origin-verify header. Alphanumeric, so it is safe inside an Apache regex."
  type        = string
  sensitive   = true
}

variable "enable_custom_domain" {
  description = "When true, attach domain_name with the ACM certificate and create the alias records. When false, the distribution keeps the default *.cloudfront.net certificate and creates no alias. The certificate and its validation CNAMEs are created either way."
  type        = bool
  default     = false
}

variable "noindex" {
  description = "When true, the response-headers policy sets X-Robots-Tag: noindex, nofollow."
  type        = bool
  default     = true
}

variable "cached_path_patterns" {
  description = "Path patterns served with a cache policy that includes the query string (WordPress ?ver= assets)."
  type        = list(string)
  default     = ["/wp-content/*", "/wp-includes/*"]
}

variable "uncached_path_patterns" {
  description = "Path patterns that are never cached. Matched before the cached patterns."
  type        = list(string)
  default     = ["/wp-admin/*", "/wp-login.php", "/wp-json/*"]
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_100 is US, Canada, and Europe."
  type        = string
  default     = "PriceClass_100"
}

variable "minimum_protocol_version" {
  description = "Minimum TLS version CloudFront accepts from viewers."
  type        = string
  default     = "TLSv1.2_2021"
}

variable "is_ipv6_enabled" {
  description = "When true, CloudFront answers AAAA and may present the viewer as an IPv6 address in CloudFront-Viewer-Address. The wp-admin allowlist has to include that address."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to resources this module creates."
  type        = map(string)
  default     = {}
}
