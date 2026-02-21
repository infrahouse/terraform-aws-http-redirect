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
  version = "2.0.0"

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
  version = "2.0.0"

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
  version = "2.0.0"

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
  version = "2.0.0"

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
  version = "2.0.0"

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

## API Endpoint Redirect (All HTTP Methods)

Redirect an API endpoint that receives POST, PUT, and DELETE requests.

**Use case:** API domain migration, service consolidation

```hcl
data "aws_route53_zone" "main" {
  name = "example.com"
}

module "api_redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "2.0.0"

  redirect_hostnames    = ["api-v1"]
  redirect_to           = "api.example.com/v2"
  zone_id               = data.aws_route53_zone.main.zone_id
  allow_non_get_methods = true

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

**Result:**

- `POST https://api-v1.example.com/users` -> `308` -> `https://api.example.com/v2/users`
- `PUT https://api-v1.example.com/users/123` -> `308` -> `https://api.example.com/v2/users/123`
- `GET https://api-v1.example.com/users` -> `301` -> `https://api.example.com/v2/users`

POST, PUT, DELETE, and PATCH requests receive a 308 (Permanent Redirect) which instructs clients
to resend the request with the same method and body to the new location.

## Custom Response Headers

Add custom headers to redirect responses for tracking or debugging.

**Use case:** Redirect attribution, monitoring integration

```hcl
data "aws_route53_zone" "main" {
  name = "example.com"
}

module "redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "2.0.0"

  redirect_hostnames = ["", "www"]
  redirect_to        = "new-domain.com"
  zone_id            = data.aws_route53_zone.main.zone_id

  response_headers = {
    "x-redirect-by"     = "infrahouse"
    "x-redirect-reason" = "domain-migration"
  }

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

**Result:**

All redirect responses include the custom headers:
```
HTTP/1.1 301 Moved Permanently
Location: https://new-domain.com/page
x-redirect-by: infrahouse
x-redirect-reason: domain-migration
```

!!! note
    Setting `response_headers` deploys a CloudFront Function to handle redirects, even if
    `allow_non_get_methods` is not enabled.

## Temporary Redirect

Use temporary redirects for maintenance pages or A/B testing.

**Use case:** Scheduled maintenance, traffic experiments

```hcl
data "aws_route53_zone" "main" {
  name = "example.com"
}

module "maintenance_redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "2.0.0"

  redirect_hostnames    = ["app"]
  redirect_to           = "status.example.com/maintenance"
  zone_id               = data.aws_route53_zone.main.zone_id
  allow_non_get_methods = true
  permanent_redirect    = false  # 302/307 instead of 301/308

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

**Result:**

- `GET https://app.example.com/` -> `302` -> `https://status.example.com/maintenance/`
- `POST https://app.example.com/api` -> `307` -> `https://status.example.com/maintenance/api`

Browsers will not cache 302/307 redirects, so removing the redirect later takes effect immediately.

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
  version = "2.0.0"

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
  version = "2.0.0"

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