variable "region" {}
variable "role_arn" {
  default = null
}

variable "test_zone_id" {}

variable "redirect_to" {
  description = "Target URL for redirect (can be hostname, hostname/path, or hostname/path?params)"
  type        = string
}

variable "create_certificate_dns_records" {
  description = "Whether to create certificate DNS records (CAA and validation CNAME)"
  type        = bool
  default     = true
}

variable "redirect_hostnames" {
  description = "List of hostname prefixes to redirect"
  type        = list(string)
  default     = ["", "foo", "bar"]
}
