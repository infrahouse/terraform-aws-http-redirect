# Minimal Cost Configuration Example
#
# This example shows the lowest-cost configuration for redirects.
# Suitable for personal domains or low-traffic scenarios.
#
# Trade-offs:
# - No CloudFront access logging (not suitable for compliance)
# - Limited to US/Canada/Europe edge locations
#
# Estimated cost: ~$1-2/month

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.62, < 7.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

data "aws_route53_zone" "redirect" {
  name = "my-domain.com"
}

module "http-redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.3.1"

  redirect_hostnames = ["", "www"]
  redirect_to        = "new-domain.com"
  zone_id            = data.aws_route53_zone.redirect.zone_id

  # Cost optimizations
  cloudfront_price_class = "PriceClass_100" # US/Canada/Europe only
  create_logging_bucket  = false            # Disable logging

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}