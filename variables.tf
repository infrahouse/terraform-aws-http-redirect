variable "redirect_hostnames" {
  description = <<-EOT
    List of hostname prefixes to redirect (e.g., ['', 'www'] for apex and www
    subdomain). Use empty string for apex domain.
  EOT
  type        = list(string)
  default     = ["", "www"]

  validation {
    condition = alltrue([
      for hostname in var.redirect_hostnames :
      can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?)?$", hostname))
    ])
    error_message = <<-EOT
      Hostname prefixes must contain only lowercase letters, numbers, and
      hyphens. They cannot contain dots (provide prefixes, not FQDNs).
    EOT
  }

  validation {
    condition     = length(var.redirect_hostnames) > 0
    error_message = "At least one hostname must be provided."
  }
}

variable "redirect_to" {
  description = <<-EOT
    Target URL where HTTP(S) requests will be redirected. Can be:
    - A hostname: 'example.com'
    - A hostname with path: 'example.com/landing'

    Note: Query parameters in redirect_to are not supported due to S3 routing
    rule limitations. Source query parameters will be preserved in redirects.
    Do not include protocol (https://).
  EOT
  type        = string

  validation {
    condition = can(regex(
      "^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*(/[^?#]*)?$",
      var.redirect_to
    ))
    error_message = <<-EOT
      redirect_to must be a valid hostname optionally followed by a path.
      Examples: 'example.com', 'example.com/path', 'example.com/landing/page'
      Query parameters are not supported.
      Do not include protocol (e.g., not 'https://example.com')
    EOT
  }
}

variable "zone_id" {
  description = "Route53 hosted zone ID where DNS records will be created"
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.zone_id))
    error_message = <<-EOT
      zone_id must be a valid Route53 zone ID (starts with Z followed by
      alphanumeric characters).
    EOT
  }
}

variable "cloudfront_price_class" {
  description = <<-EOT
    CloudFront distribution price class. Controls which edge locations are used
    and affects cost:
    - PriceClass_100: US, Canada, Europe (lowest cost)
    - PriceClass_200: PriceClass_100 + Asia, Africa, Oceania, Middle East
    - PriceClass_All: All edge locations (highest cost, best performance globally)
  EOT
  type        = string
  default     = "PriceClass_100"

  validation {
    condition = contains([
      "PriceClass_100",
      "PriceClass_200",
      "PriceClass_All"
    ], var.cloudfront_price_class)
    error_message = <<-EOT
      cloudfront_price_class must be one of: PriceClass_100, PriceClass_200, or PriceClass_All.
    EOT
  }
}

variable "create_logging_bucket" {
  description = <<-EOT
    Create an S3 bucket for CloudFront logs using infrahouse/s3-bucket/aws module.
    Enables ISO 27001/SOC 2 compliant logging by default. Set to false to disable
    logging (not recommended for production).
  EOT
  type        = bool
  default     = true
}

variable "cloudfront_logging_prefix" {
  description = "Prefix for CloudFront log files in the logging bucket"
  type        = string
  default     = "cloudfront-logs/"
}

variable "cloudfront_logging_include_cookies" {
  description = "Include cookies in CloudFront logs"
  type        = bool
  default     = false
}

variable "cloudfront_logging_bucket_force_destroy" {
  description = <<-EOT
    Allow destruction of the CloudFront logging bucket even if it contains log files.
    Set to true in test/dev environments. Should remain false in production to prevent
    accidental data loss.
  EOT
  type        = bool
  default     = false
}

variable "web_acl_id" {
  description = <<-EOT
    Optional AWS WAF Web ACL ARN to attach to the CloudFront distribution.
    Provides DDoS protection and rate limiting for the redirect service.

    Leave null (default) for most use cases. Consider enabling if:
    - You have compliance requirements for WAF on all resources
    - You're experiencing abuse or high request volumes
    - You need IP-based access controls

    Note: AWS WAF incurs additional costs per web ACL and per million requests.
  EOT
  type        = string
  default     = null
}
