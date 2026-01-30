variable "zone_id" {
  description = "Route53 zone ID for testing"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "role_arn" {
  description = "IAM role ARN for testing"
  type        = string
  default     = null
}