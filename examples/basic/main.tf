# Basic HTTP Redirect Example
#
# This example shows the simplest use case: redirecting a domain and its
# www subdomain to a new domain.
#
# Usage:
#   1. Update the zone name to your domain
#   2. Update redirect_to to your target domain
#   3. Run: terraform init && terraform apply

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

# Primary provider - your main region
provider "aws" {
  region = "us-west-2"
}

# Required for ACM certificates (CloudFront requirement)
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

# Look up your existing Route 53 hosted zone
data "aws_route53_zone" "redirect" {
  name = "example.com" # Replace with your domain
}

# Create the redirect
module "http-redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "2.0.0"

  # Redirect apex domain and www subdomain
  redirect_hostnames = ["", "www"]

  # Target domain (without https://)
  redirect_to = "target.com"

  # Route 53 zone for DNS records
  zone_id = data.aws_route53_zone.redirect.zone_id

  # Replicate the CloudFront log bucket to a second region (compliance).
  # Must differ from the bucket's region (us-west-2 above).
  replication_region = "us-east-1"

  # Pass both providers to the module
  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}