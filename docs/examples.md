# Examples

This page demonstrates common use cases for the terraform-aws-http-redirect module.

## Basic Domain Redirect

Redirect a domain and its www subdomain to a new domain.

**Use case:** Domain consolidation, company rebranding

```hcl
provider "aws" {
  region = "us-west-2"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

data "aws_route53_zone" "old_domain" {
  name = "old-company.com"
}

module "redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.0.1"

  redirect_hostnames = ["", "www"]
  redirect_to        = "new-company.com"
  zone_id            = data.aws_route53_zone.old_domain.zone_id

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

**Result:**

- `https://old-company.com/` → `https://new-company.com/`
- `https://www.old-company.com/` → `https://new-company.com/`
- `https://old-company.com/about` → `https://new-company.com/about`

## Redirect to Specific Path

Redirect to a landing page on the target domain.

**Use case:** Marketing campaigns, product deprecation

```hcl
data "aws_route53_zone" "main" {
  name = "example.com"
}

module "campaign_redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.0.1"

  redirect_hostnames = ["promo", "sale"]
  redirect_to        = "store.example.com/summer-sale"
  zone_id            = data.aws_route53_zone.main.zone_id

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

**Result:**

- `https://promo.example.com/` → `https://store.example.com/summer-sale/`
- `https://promo.example.com/details` → `https://store.example.com/summer-sale/details`

## Multiple Subdomain Redirect

Redirect multiple legacy subdomains to a new location.

**Use case:** Service migration, subdomain cleanup

```hcl
data "aws_route53_zone" "main" {
  name = "example.com"
}

module "legacy_redirects" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.0.1"

  redirect_hostnames = [
    "app-v1",
    "app-v2",
    "legacy",
    "old-dashboard"
  ]
  redirect_to = "app.example.com"
  zone_id     = data.aws_route53_zone.main.zone_id

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

## Minimal Cost Configuration

Optimized for lowest possible cost.

**Use case:** Low-traffic redirects, personal domains

```hcl
data "aws_route53_zone" "main" {
  name = "my-domain.com"
}

module "redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.0.1"

  redirect_hostnames = ["", "www"]
  redirect_to        = "my-new-domain.com"
  zone_id            = data.aws_route53_zone.main.zone_id

  # Cost optimizations
  cloudfront_price_class = "PriceClass_100"  # US/Canada/Europe only
  create_logging_bucket  = false             # Disable logging

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

**Estimated monthly cost:** ~$1-2

!!! warning
    Disabling logging is not recommended for production environments with compliance
    requirements.

## Production Configuration with WAF

Full-featured production setup with WAF protection.

**Use case:** Enterprise deployments, compliance requirements

```hcl
provider "aws" {
  region = "us-west-2"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

# WAF Web ACL for DDoS protection
resource "aws_wafv2_web_acl" "redirect" {
  provider = aws.us-east-1  # WAF for CloudFront must be in us-east-1
  name     = "redirect-protection"
  scope    = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "rate-limit"
    priority = 1

    override_action {
      none {}
    }

    statement {
      rate_based_statement {
        limit              = 10000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "redirect-waf"
    sampled_requests_enabled   = true
  }
}

data "aws_route53_zone" "main" {
  name = "enterprise.com"
}

module "redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.0.1"

  redirect_hostnames = ["", "www"]
  redirect_to        = "new-enterprise.com"
  zone_id            = data.aws_route53_zone.main.zone_id

  # Production settings
  cloudfront_price_class                  = "PriceClass_All"
  create_logging_bucket                   = true
  cloudfront_logging_prefix               = "production/enterprise-redirect/"
  cloudfront_logging_bucket_force_destroy = false  # Protect logs
  web_acl_id                              = aws_wafv2_web_acl.redirect.arn

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

## Multiple Redirects in Same Account

Create multiple independent redirects.

```hcl
data "aws_route53_zone" "domain_a" {
  name = "domain-a.com"
}

data "aws_route53_zone" "domain_b" {
  name = "domain-b.com"
}

module "redirect_a" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.0.1"

  redirect_hostnames = ["", "www"]
  redirect_to        = "main-site.com"
  zone_id            = data.aws_route53_zone.domain_a.zone_id

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}

module "redirect_b" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.0.1"

  redirect_hostnames = ["", "www"]
  redirect_to        = "main-site.com/partner"
  zone_id            = data.aws_route53_zone.domain_b.zone_id

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

## Working Examples

Complete working examples are available in the repository:

- [examples/basic/](https://github.com/infrahouse/terraform-aws-http-redirect/tree/main/examples/basic) - Simple domain redirect
- [examples/with-path/](https://github.com/infrahouse/terraform-aws-http-redirect/tree/main/examples/with-path) - Redirect to specific path
- [examples/minimal-cost/](https://github.com/infrahouse/terraform-aws-http-redirect/tree/main/examples/minimal-cost) - Lowest cost configuration