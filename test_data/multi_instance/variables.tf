variable "region" {
  description = "AWS region for test resources"
  type        = string
}

variable "role_arn" {
  description = "IAM role ARN to assume for test execution"
  type        = string
  default     = null
}

variable "test_zone_id" {
  description = "Route53 zone ID for test DNS records"
  type        = string
}

variable "redirect_to_1" {
  description = "Target URL for first redirect instance"
  type        = string
}

variable "redirect_hostnames_1" {
  description = "Hostname prefixes for first redirect instance"
  type        = list(string)
}

variable "redirect_to_2" {
  description = "Target URL for second redirect instance"
  type        = string
}

variable "redirect_hostnames_2" {
  description = "Hostname prefixes for second redirect instance"
  type        = list(string)
}
