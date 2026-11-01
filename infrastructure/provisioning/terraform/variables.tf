variable "domain_name" {
  description = "DNS domain name for the Route 53 hosted zone."
  type        = string
  default     = "paulserban.eu"
}

# DNS record values are supplied as TF_VAR_* from .env. See .env.example.
# None of these are AWS credentials. Google and Bing tokens are low sensitivity;
# ACM validation CNAMEs and the DMARC policy are public by design.

variable "google_site_verification_token" {
  description = "Google Search Console ownership verification token. Low sensitivity: not an API key. Publishing it can let someone prove domain ownership to Google."
  type        = string
}

variable "bing_site_verification_token" {
  description = "Bing Webmaster Tools ownership verification token. Low sensitivity: not a credential. Publicly discoverable through DNS. Used as the CNAME label for apex, blog, news-feed, and www."
  type        = string
}

variable "dmarc_policy" {
  description = "DMARC TXT policy. Public email authentication policy. p=none is monitoring only."
  type        = string
}

variable "acm_validation_apex_412c69c3_name" {
  description = "ACM DNS validation label for the apex (first record), including the leading underscore and excluding the domain. Public by design; not an AWS credential."
  type        = string
}

variable "acm_validation_apex_412c69c3_target" {
  description = "ACM DNS validation CNAME target for the apex (first record). Public by design; not an AWS credential."
  type        = string
}

variable "acm_validation_apex_a6b6bc87_name" {
  description = "ACM DNS validation label for the apex (second record), including the leading underscore and excluding the domain. Public by design; not an AWS credential."
  type        = string
}

variable "acm_validation_apex_a6b6bc87_target" {
  description = "ACM DNS validation CNAME target for the apex (second record). Public by design; not an AWS credential."
  type        = string
}

variable "acm_validation_assets_name" {
  description = "ACM DNS validation label for assets.<domain>, including the leading underscore and excluding the hostname. Public by design; not an AWS credential."
  type        = string
}

variable "acm_validation_assets_target" {
  description = "ACM DNS validation CNAME target for assets.<domain>. Public by design; not an AWS credential."
  type        = string
}

variable "acm_validation_blog_name" {
  description = "ACM DNS validation label for blog.<domain>, including the leading underscore and excluding the hostname. Public by design; not an AWS credential."
  type        = string
}

variable "acm_validation_blog_target" {
  description = "ACM DNS validation CNAME target for blog.<domain>. Public by design; not an AWS credential."
  type        = string
}

variable "acm_validation_news_data_name" {
  description = "ACM DNS validation label for news-data.<domain>, including the leading underscore and excluding the hostname. Public by design; not an AWS credential."
  type        = string
}

variable "acm_validation_news_data_target" {
  description = "ACM DNS validation CNAME target for news-data.<domain>. Public by design; not an AWS credential."
  type        = string
}

variable "acm_validation_news_feed_name" {
  description = "ACM DNS validation label for news-feed.<domain>, including the leading underscore and excluding the hostname. Public by design; not an AWS credential."
  type        = string
}

variable "acm_validation_news_feed_target" {
  description = "ACM DNS validation CNAME target for news-feed.<domain>. Public by design; not an AWS credential."
  type        = string
}

variable "acm_validation_quiz_name" {
  description = "ACM DNS validation label for quiz.<domain>, including the leading underscore and excluding the hostname. Public by design; not an AWS credential."
  type        = string
}

variable "acm_validation_quiz_target" {
  description = "ACM DNS validation CNAME target for quiz.<domain>. Public by design; not an AWS credential."
  type        = string
}

variable "acm_validation_www_name" {
  description = "ACM DNS validation label for www.<domain>, including the leading underscore and excluding the hostname. Public by design; not an AWS credential."
  type        = string
}

variable "acm_validation_www_target" {
  description = "ACM DNS validation CNAME target for www.<domain>. Public by design; not an AWS credential."
  type        = string
}
