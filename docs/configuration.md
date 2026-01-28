# Configuration

This page documents all configuration options for the terraform-aws-http-redirect module.

## Required Variables

### redirect_to

The target domain where requests will be redirected.

| Attribute | Value |
|-----------|-------|
| Type | `string` |
| Required | Yes |

**Formats supported:**

- Hostname only: `example.com`
- Hostname with path: `example.com/landing`

**Examples:**

```hcl
# Redirect to hostname
redirect_to = "new-domain.com"

# Redirect to specific path
redirect_to = "new-domain.com/welcome"
```

!!! warning
    Do not include the protocol (`https://`). Query parameters in `redirect_to` are not
    supported due to S3 routing rule limitations.

### zone_id

The Route 53 hosted zone ID where DNS records will be created.

| Attribute | Value |
|-----------|-------|
| Type | `string` |
| Required | Yes |

**Example:**

```hcl
data "aws_route53_zone" "main" {
  name = "example.com"
}

module "redirect" {
  # ...
  zone_id = data.aws_route53_zone.main.zone_id
}
```

## Optional Variables

### redirect_hostnames

List of hostname prefixes to redirect.

| Attribute | Value |
|-----------|-------|
| Type | `list(string)` |
| Default | `["", "www"]` |

**Special values:**

- Empty string (`""`) = apex domain (e.g., `example.com`)
- Any string = subdomain (e.g., `"www"` becomes `www.example.com`)

**Examples:**

```hcl
# Apex and www (default)
redirect_hostnames = ["", "www"]

# Multiple subdomains
redirect_hostnames = ["old", "legacy", "deprecated"]

# Only apex domain
redirect_hostnames = [""]
```

### cloudfront_price_class

Controls which CloudFront edge locations are used, directly impacting cost.

| Attribute | Value |
|-----------|-------|
| Type | `string` |
| Default | `"PriceClass_100"` |

**Options:**

| Price Class | Edge Locations | Monthly Cost* |
|-------------|----------------|---------------|
| `PriceClass_100` | US, Canada, Europe | ~$1-5 |
| `PriceClass_200` | + Asia, Africa, Oceania, Middle East | ~$2-10 |
| `PriceClass_All` | All worldwide | ~$3-15 |

*Estimated for low-traffic redirect (<10,000 requests/month)

**Example:**

```hcl
# Global coverage for international users
cloudfront_price_class = "PriceClass_All"
```

### create_logging_bucket

Whether to create an S3 bucket for CloudFront access logs.

| Attribute | Value |
|-----------|-------|
| Type | `bool` |
| Default | `true` |

Logging is enabled by default for ISO 27001/SOC 2 compliance. Set to `false` to disable
logging (not recommended for production).

**Example:**

```hcl
# Disable logging for development
create_logging_bucket = false
```

### cloudfront_logging_prefix

Prefix for CloudFront log files in the logging bucket.

| Attribute | Value |
|-----------|-------|
| Type | `string` |
| Default | `"cloudfront-logs/"` |

**Example:**

```hcl
cloudfront_logging_prefix = "redirects/example-com/"
```

### cloudfront_logging_include_cookies

Whether to include cookies in CloudFront logs.

| Attribute | Value |
|-----------|-------|
| Type | `bool` |
| Default | `false` |

### cloudfront_logging_bucket_force_destroy

Allow destruction of the logging bucket even if it contains log files.

| Attribute | Value |
|-----------|-------|
| Type | `bool` |
| Default | `false` |

!!! danger
    Set to `true` only in test/dev environments. In production, this should remain `false`
    to prevent accidental data loss.

**Example:**

```hcl
# Allow bucket deletion in development
cloudfront_logging_bucket_force_destroy = true
```

### web_acl_id

Optional AWS WAF Web ACL ARN to attach to the CloudFront distribution.

| Attribute | Value |
|-----------|-------|
| Type | `string` |
| Default | `null` |

**When to use:**

- Compliance requirements mandate WAF on all resources
- You're experiencing abuse or high request volumes
- You need IP-based access controls

**Example:**

```hcl
resource "aws_wafv2_web_acl" "redirect" {
  name  = "redirect-protection"
  scope = "CLOUDFRONT"
  # ... WAF configuration
}

module "redirect" {
  # ...
  web_acl_id = aws_wafv2_web_acl.redirect.arn
}
```

!!! note
    AWS WAF incurs additional costs: $5/month per web ACL + $1 per million requests.

### dns_routing_policy

DNS routing policy for Route53 records.

| Attribute | Value |
|-----------|-------|
| Type | `string` |
| Default | `"simple"` |

**Options:**

| Policy | Description |
|--------|-------------|
| `simple` | Standard DNS routing (default) |
| `weighted` | Weighted routing for gradual traffic migration |

Use `weighted` for zero-downtime migrations when transitioning traffic from an existing
service to the redirect.

### dns_weight

Weight for weighted routing policy (0-255).

| Attribute | Value |
|-----------|-------|
| Type | `number` |
| Default | `100` |

Only used when `dns_routing_policy = "weighted"`. Higher values receive proportionally more
traffic relative to other weighted records with the same name.

### dns_set_identifier

Unique identifier for weighted routing records.

| Attribute | Value |
|-----------|-------|
| Type | `string` |
| Default | `null` |

Required when `dns_routing_policy = "weighted"`. Must be unique among all weighted records
with the same DNS name.

**Example: Zero-Downtime Migration**

When deprecating a service and redirecting users to a new URL, weighted routing allows
gradual traffic shifting:

```hcl
# Step 1: Deploy redirect with weight=0
module "redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.1.0"

  redirect_to        = "new-service.example.com"
  zone_id            = data.aws_route53_zone.main.zone_id
  redirect_hostnames = ["old-service"]

  # Weighted routing configuration
  dns_routing_policy = "weighted"
  dns_weight         = 0
  dns_set_identifier = "redirect"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}

# Step 2: Convert existing service DNS to weighted with weight=100
# Step 3: Gradually shift weights (90/10 → 50/50 → 10/90 → 0/100)
# Step 4: Remove old service weighted record
# Step 5: Optionally convert redirect back to simple routing
```

## Outputs

### CloudFront Outputs

| Output | Description |
|--------|-------------|
| `cloudfront_distribution_id` | CloudFront distribution identifier |
| `cloudfront_distribution_arn` | CloudFront distribution ARN |
| `cloudfront_domain_name` | CloudFront domain (e.g., `d111111abcdef8.cloudfront.net`) |

### S3 Outputs

| Output | Description |
|--------|-------------|
| `s3_bucket_name` | S3 redirect bucket name |
| `s3_bucket_arn` | S3 redirect bucket ARN |
| `cloudfront_logs_bucket_name` | Logging bucket name (null if disabled) |
| `cloudfront_logs_bucket_arn` | Logging bucket ARN (null if disabled) |

### DNS Outputs

| Output | Description |
|--------|-------------|
| `redirect_domains` | List of FQDNs being redirected |
| `dns_a_records` | Map of A records created |
| `dns_aaaa_records` | Map of AAAA records created |
| `caa_records` | Map of CAA records created |

### Certificate Outputs

| Output | Description |
|--------|-------------|
| `acm_certificate_arn` | ACM certificate ARN (us-east-1) |

## Complete Example

```hcl
provider "aws" {
  region = "us-west-2"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

data "aws_route53_zone" "main" {
  name = "example.com"
}

module "http-redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.1.0"

  # Required
  redirect_to = "new-domain.com"
  zone_id     = data.aws_route53_zone.main.zone_id

  # Optional - customize as needed
  redirect_hostnames       = ["", "www", "old"]
  cloudfront_price_class   = "PriceClass_200"
  create_logging_bucket    = true
  cloudfront_logging_prefix = "redirects/example-com/"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}

output "distribution_id" {
  value = module.http-redirect.cloudfront_distribution_id
}
```