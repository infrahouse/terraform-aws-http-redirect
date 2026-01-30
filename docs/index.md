# terraform-aws-http-redirect

A Terraform module that creates HTTP/HTTPS redirects using AWS CloudFront, S3, ACM, and Route53.
Perfect for domain consolidation, vanity URLs, and SEO-friendly permanent redirects.

## Overview

This module handles the complexity of setting up HTTP redirects in AWS by creating and
configuring multiple services automatically:

- **CloudFront Distribution**: TLS termination, HTTP-to-HTTPS redirect, caching
- **S3 Bucket**: Static website hosting with redirect routing rules
- **ACM Certificate**: Automatic provisioning and DNS validation in us-east-1
- **Route 53 Records**: A/AAAA aliases and CAA records for the redirect domains

## Why This Module?

Setting up HTTP redirects in AWS typically requires configuring multiple services manually.
This module handles all of that complexity in a single, well-tested package.

| Approach | Monthly Cost | Complexity | Features |
|----------|-------------|------------|----------|
| **This module** | ~$1-5 | Low | TLS, security headers, logging |
| Manual setup | ~$1-5 | High | Same features, ~200 lines of Terraform |
| ALB redirects | ~$16+ | Medium | Requires VPC, EC2 infrastructure |
| S3-only | ~$0.50 | Low | No TLS, no security headers |
| Third-party | Varies | Low | Vendor lock-in |

## Features

- **Permanent HTTPS Redirects**: HTTP 301 redirects that preserve paths and query strings
- **Automatic TLS**: ACM certificate provisioning and DNS validation (zero manual steps)
- **Security Headers**: HSTS, X-Frame-Options, X-Content-Type-Options pre-configured
- **Compliance Logging**: ISO 27001/SOC 2 compliant CloudFront access logging
- **Cost Optimized**: CloudFront price class selection for budget control
- **WAF Ready**: Optional AWS WAF integration for DDoS protection
- **Multi-hostname Support**: Redirect apex domain and subdomains with one module call

## Quick Start

```hcl
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
  version = "1.2.0"

  redirect_hostnames = ["", "www"]
  redirect_to        = "target.com"
  zone_id            = data.aws_route53_zone.redirect.zone_id

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

This redirects `example.com` and `www.example.com` to `target.com`, preserving paths and
query strings.

## Redirect Behavior

| Source URL | Target URL |
|------------|------------|
| `https://example.com/` | `https://target.com/` |
| `https://example.com/page` | `https://target.com/page` |
| `https://example.com/page?query=1` | `https://target.com/page?query=1` |
| `http://example.com/page` | `https://target.com/page` (HTTP upgraded to HTTPS) |

## Next Steps

- [Getting Started](getting-started.md) - Prerequisites and first deployment
- [Configuration](configuration.md) - All variables explained
- [Architecture](architecture.md) - How it works
- [Examples](examples.md) - Common use cases