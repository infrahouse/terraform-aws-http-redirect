variable "region" {}
variable "role_arn" {
  default = null
}

variable "test_zone_id" {}

variable "redirect_to" {
  description = "Target URL for redirect (can be hostname, hostname/path, or hostname/path?params)"
  type        = string
}
