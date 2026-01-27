# Redirect to Specific Path Example
#
# This example shows how to redirect to a specific path on the target domain.
# All requests will have the path prepended to their original path.
#
# Usage:
#   1. Update the zone name to your domain
#   2. Update redirect_to to your target domain and path
#   3. Run: terraform init && terraform apply

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
  name = "example.com"
}

module "http-redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.0.1"

  # Redirect specific subdomains
  redirect_hostnames = ["old-app", "legacy"]

  # Target domain WITH path
  # The path will be prepended to the original request path
  redirect_to = "new-app.example.com/migrated"

  zone_id = data.aws_route53_zone.redirect.zone_id

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}