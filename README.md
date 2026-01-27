# terraform-aws-http-redirect

[![Need Help?](https://img.shields.io/badge/Need%20Help%3F-Contact%20Us-0066CC)](https://infrahouse.com/contact)
[![Docs](https://img.shields.io/badge/docs-github.io-blue)](https://infrahouse.github.io/terraform-aws-http-redirect/)
[![Registry](https://img.shields.io/badge/Terraform-Registry-purple?logo=terraform)](https://registry.terraform.io/modules/infrahouse/http-redirect/aws/latest)
[![Release](https://img.shields.io/github/release/infrahouse/terraform-aws-http-redirect.svg)](https://github.com/infrahouse/terraform-aws-http-redirect/releases/latest)
[![Security](https://img.shields.io/github/actions/workflow/status/infrahouse/terraform-aws-http-redirect/vuln-scanner-pr.yml?label=Security)](https://github.com/infrahouse/terraform-aws-http-redirect/actions/workflows/vuln-scanner-pr.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

[![AWS CloudFront](https://img.shields.io/badge/AWS-CloudFront-orange?logo=amazoncloudwatch)](https://aws.amazon.com/cloudfront/)
[![AWS S3](https://img.shields.io/badge/AWS-S3-orange?logo=amazons3)](https://aws.amazon.com/s3/)
[![AWS Route53](https://img.shields.io/badge/AWS-Route53-orange?logo=amazonroute53)](https://aws.amazon.com/route53/)

A Terraform module that creates HTTP/HTTPS redirects using AWS CloudFront, S3, ACM, and Route53.
Perfect for domain consolidation, vanity URLs, and SEO-friendly permanent redirects.

## Why This Module?

Setting up HTTP redirects in AWS typically requires configuring multiple services manually:
CloudFront distributions, S3 buckets with website hosting, ACM certificates, and DNS records.
This module handles all of that complexity in a single, well-tested package.

**Compared to alternatives:**

- **Manual setup**: This module reduces ~200 lines of Terraform to ~10 lines
- **ALB redirects**: CloudFront is more cost-effective for simple redirects (~$1-5/month vs $16+/month)
- **S3-only redirects**: This module adds TLS termination, security headers, and compliance logging
- **Third-party services**: Keep your infrastructure in AWS with full control and no vendor lock-in

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
  version = "1.0.1"

  redirect_hostnames = ["", "www"]
  redirect_to        = "target.com"
  zone_id            = data.aws_route53_zone.redirect.zone_id

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

This redirects `example.com` and `www.example.com` to `target.com`, preserving paths and query strings.

## Documentation

Full documentation is available at [infrahouse.github.io/terraform-aws-http-redirect](https://infrahouse.github.io/terraform-aws-http-redirect/):

- [Getting Started](https://infrahouse.github.io/terraform-aws-http-redirect/getting-started/) - Prerequisites and first deployment
- [Configuration](https://infrahouse.github.io/terraform-aws-http-redirect/configuration/) - All variables explained
- [Architecture](https://infrahouse.github.io/terraform-aws-http-redirect/architecture/) - How it works
- [Examples](https://infrahouse.github.io/terraform-aws-http-redirect/examples/) - Common use cases
- [Troubleshooting](https://infrahouse.github.io/terraform-aws-http-redirect/troubleshooting/) - Common issues and solutions

## Usage

### Basic Hostname Redirect

Redirect domains like:
```
example.com → target.com
www.example.com → target.com
```
Useful for domain consolidation, vanity URLs, or SEO cleanup.

```hcl
data "aws_route53_zone" "redirect" {
  name = "example.com"
}

module "http-redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.0.1"

  redirect_hostnames = ["", "www"]
  redirect_to        = "bar.com"
  zone_id            = data.aws_route53_zone.redirect.zone_id
}
```

**Behavior:**
- `https://example.com/` → `https://bar.com/`
- `https://example.com/page` → `https://bar.com/page`
- `https://example.com/page?query=1` → `https://bar.com/page?query=1`

> Paths and query strings are always preserved during redirects.

### Redirect to Specific Path

Redirect to a specific path on the target domain:

```hcl
module "http-redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.0.1"

  redirect_hostnames = ["old-site", "legacy"]
  redirect_to        = "new-site.com/welcome"
  zone_id            = data.aws_route53_zone.redirect.zone_id
}
```

**Behavior:**
- `https://old-site.example.com/` → `https://new-site.com/welcome/`
- `https://old-site.example.com/about` → `https://new-site.com/welcome/about`
- `https://old-site.example.com/contact?ref=email` → `https://new-site.com/welcome/contact?ref=email`

> The redirect path is prepended to the request path, and query strings are preserved.

### Provider Configuration

**CRITICAL:** This module requires a dual-provider configuration. CloudFront requires ACM certificates to be in the `us-east-1` region, regardless of where other resources are created.

```hcl
# Configure the main AWS provider for your desired region
provider "aws" {
  region = "us-west-2"  # Your primary region
}

# Configure a second provider specifically for us-east-1
# This is required for ACM certificate provisioning
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

  redirect_hostnames = ["", "www"]
  redirect_to        = "target.com"
  zone_id            = data.aws_route53_zone.redirect.zone_id

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

**Why us-east-1?** CloudFront is a global service that requires ACM certificates to be provisioned in the `us-east-1` region. This is an AWS requirement, not a module limitation. The module automatically handles this by using the `aws.us-east-1` provider for certificate operations while creating other resources in your primary region.

## Cost Considerations

This module creates several AWS resources with associated costs:

### CloudFront Price Classes

The `cloudfront_price_class` variable controls which edge locations are used and directly impacts cost:

| Price Class | Edge Locations | Typical Monthly Cost* | Use Case |
|-------------|----------------|----------------------|----------|
| `PriceClass_100` | US, Canada, Europe | ~$1-5 | Lowest cost, good for North America/Europe traffic |
| `PriceClass_200` | PriceClass_100 + Asia, Africa, Oceania, Middle East | ~$2-10 | Moderate cost, broader geographic coverage |
| `PriceClass_All` | All edge locations worldwide | ~$3-15 | Highest cost, best global performance |

\* Estimated for a low-traffic redirect service (< 10,000 requests/month). Actual costs depend on request volume and data transfer.

### Additional Costs

- **S3 Storage**: Negligible (< $0.10/month) - bucket contains only redirect configuration
- **Route 53 Hosted Zone**: $0.50/month per zone (if not already existing)
- **Route 53 Queries**: $0.40 per million queries for A/AAAA records
- **ACM Certificate**: Free
- **CloudFront Requests**: $0.0075-0.016 per 10,000 HTTPS requests (varies by region)
- **WAF (if enabled)**: $5/month per web ACL + $1 per million requests

**Recommendation:** Start with `PriceClass_100` (default) for most use cases. Upgrade to `PriceClass_200` or `PriceClass_All` only if you need better performance in Asia-Pacific, Africa, or South America.

For detailed AWS pricing, see:
- [CloudFront Pricing](https://aws.amazon.com/cloudfront/pricing/)
- [Route 53 Pricing](https://aws.amazon.com/route53/pricing/)
- [AWS WAF Pricing](https://aws.amazon.com/waf/pricing/)

## Troubleshooting

### Common Issues

#### Certificate Validation Timeout

**Error:** `Error waiting for ACM Certificate validation: timeout while waiting for state to become 'ISSUED'`

**Cause:** DNS validation records not properly created or propagated.

**Solution:**
1. Verify the Route 53 hosted zone is publicly accessible:
   ```bash
   dig NS example.com
   ```
2. Check that nameservers match your Route 53 zone's NS records
3. Wait 5-10 minutes for DNS propagation
4. Retry `terraform apply`

#### Provider Configuration Error

**Error:** `Provider configuration not present` or `Module does not support aws.us-east-1 provider`

**Cause:** Missing or incorrect provider configuration.

**Solution:** Ensure you have both providers configured (see Provider Configuration section above):
```hcl
provider "aws" {
  region = "us-west-2"  # Your region
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

module "http-redirect" {
  # ... other configuration ...
  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

#### Redirect Not Working

**Symptoms:** Accessing the domain shows CloudFront error or times out.

**Solution:**
1. Verify DNS records are created:
   ```bash
   dig A www.example.com
   dig AAAA www.example.com
   ```
   Should point to CloudFront distribution (format: `d111111abcdef8.cloudfront.net`)

2. Check CloudFront distribution status:
   ```bash
   aws cloudfront get-distribution --id <distribution-id>
   ```
   Status should be "Deployed" (initial deployment takes 15-30 minutes)

3. Test redirect manually:
   ```bash
   curl -I https://www.example.com
   ```
   Should return HTTP 301 with Location header

#### S3 Bucket Name Conflict

**Error:** `BucketAlreadyExists` or `BucketAlreadyOwnedByYou`

**Cause:** S3 bucket names are globally unique. Someone else may own the bucket name derived from your hostname.

**Solution:** This typically happens if:
- You previously created and deleted the bucket (takes 24 hours to fully delete)
- Another AWS account owns a bucket with the same name

Wait 24 hours and retry, or choose a different hostname prefix that generates a unique bucket name.

### Verification Steps

After successful deployment, verify the redirect works:

```bash
# Test HTTP to HTTPS redirect
curl -I http://www.example.com

# Test HTTPS redirect to target
curl -I https://www.example.com

# Test path preservation
curl -I https://www.example.com/some/path

# Test query string preservation
curl -I "https://www.example.com/page?foo=bar&baz=qux"
```

Expected responses:
- HTTP request: 301 redirect to HTTPS version
- HTTPS request: 301 redirect to target domain
- Location header should preserve path and query parameters

### Logging and Debugging

CloudFront access logs (enabled by default) are stored in the S3 logging bucket:

```bash
# List recent log files
aws s3 ls s3://example-com-cloudfront-logs/cloudfront-logs/ --recursive

# Download and analyze logs
aws s3 cp s3://example-com-cloudfront-logs/cloudfront-logs/ ./logs/ --recursive
```

Log format: [CloudFront Standard Log Format](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/AccessLogs.html#BasicDistributionFileFormat)

## Architecture

This module creates the following AWS resources:

```
┌─────────────────────────────────────────────────────────────────┐
│                         DNS Resolution                          │
│  example.com, www.example.com (Route 53 A/AAAA records)         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   CloudFront Distribution                       │
│  • TLS termination (ACM certificate from us-east-1)             │
│  • HTTP → HTTPS redirect (viewer protocol policy)               │
│  • Caching with query string forwarding                         │
│  • Security headers (HSTS, X-Frame-Options, etc.)               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              S3 Bucket (Website Hosting Mode)                   │
│  • Routing rules for redirects                                  │
│  • Preserves paths and query strings                            │
│  • Returns HTTP 301 to target domain                            │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
                  target.com/path
```

**Data Flow:**

1. User requests `https://www.example.com/page?foo=bar`
2. DNS resolves to CloudFront distribution
3. CloudFront terminates TLS using ACM certificate (from us-east-1)
4. CloudFront forwards request to S3 website endpoint
5. S3 returns HTTP 301 with Location: `https://target.com/page?foo=bar`
6. CloudFront caches response and returns to user
7. User's browser follows redirect to target domain

**Key Resources:**

- **Route 53 Records**: A/AAAA aliases pointing to CloudFront
- **CloudFront Distribution**: Global CDN with TLS and caching
- **ACM Certificate**: TLS certificate (us-east-1 only)
- **S3 Bucket**: Static website with redirect rules
- **CloudFront Logs Bucket**: Access logs for compliance and debugging
- **Security Policies**: Cache policy + Response headers policy

### Notes

- Make sure the hosted zone exists in Route 53
- Redirects use HTTP 301 (permanent redirect)
- Query parameters in `redirect_to` are not supported (use path only)

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.62, < 7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.62, < 7.0 |
| <a name="provider_aws.us-east-1"></a> [aws.us-east-1](#provider\_aws.us-east-1) | >= 5.62, < 7.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cloudfront_logs_bucket"></a> [cloudfront\_logs\_bucket](#module\_cloudfront\_logs\_bucket) | registry.infrahouse.com/infrahouse/s3-bucket/aws | 0.3.0 |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_cloudfront_cache_policy.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_cache_policy) | resource |
| [aws_cloudfront_distribution.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_response_headers_policy.security_headers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_response_headers_policy) | resource |
| [aws_route53_record.caa_record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.extra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.extra_aaaa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_website_configuration.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_website_configuration) | resource |
| [aws_iam_policy_document.cloudfront_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.enforce_ssl_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_route53_zone.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudfront_logging_bucket_force_destroy"></a> [cloudfront\_logging\_bucket\_force\_destroy](#input\_cloudfront\_logging\_bucket\_force\_destroy) | Allow destruction of the CloudFront logging bucket even if it contains log files.<br/>Set to true in test/dev environments. Should remain false in production to prevent<br/>accidental data loss. | `bool` | `false` | no |
| <a name="input_cloudfront_logging_include_cookies"></a> [cloudfront\_logging\_include\_cookies](#input\_cloudfront\_logging\_include\_cookies) | Include cookies in CloudFront logs | `bool` | `false` | no |
| <a name="input_cloudfront_logging_prefix"></a> [cloudfront\_logging\_prefix](#input\_cloudfront\_logging\_prefix) | Prefix for CloudFront log files in the logging bucket | `string` | `"cloudfront-logs/"` | no |
| <a name="input_cloudfront_price_class"></a> [cloudfront\_price\_class](#input\_cloudfront\_price\_class) | CloudFront distribution price class. Controls which edge locations are used<br/>and affects cost:<br/>- PriceClass\_100: US, Canada, Europe (lowest cost)<br/>- PriceClass\_200: PriceClass\_100 + Asia, Africa, Oceania, Middle East<br/>- PriceClass\_All: All edge locations (highest cost, best performance globally) | `string` | `"PriceClass_100"` | no |
| <a name="input_create_logging_bucket"></a> [create\_logging\_bucket](#input\_create\_logging\_bucket) | Create an S3 bucket for CloudFront logs using infrahouse/s3-bucket/aws module.<br/>Enables ISO 27001/SOC 2 compliant logging by default. Set to false to disable<br/>logging (not recommended for production). | `bool` | `true` | no |
| <a name="input_redirect_hostnames"></a> [redirect\_hostnames](#input\_redirect\_hostnames) | List of hostname prefixes to redirect (e.g., ['', 'www'] for apex and www<br/>subdomain). Use empty string for apex domain. | `list(string)` | <pre>[<br/>  "",<br/>  "www"<br/>]</pre> | no |
| <a name="input_redirect_to"></a> [redirect\_to](#input\_redirect\_to) | Target URL where HTTP(S) requests will be redirected. Can be:<br/>- A hostname: 'example.com'<br/>- A hostname with path: 'example.com/landing'<br/><br/>Note: Query parameters in redirect\_to are not supported due to S3 routing<br/>rule limitations. Source query parameters will be preserved in redirects.<br/>Do not include protocol (https://). | `string` | n/a | yes |
| <a name="input_web_acl_id"></a> [web\_acl\_id](#input\_web\_acl\_id) | Optional AWS WAF Web ACL ARN to attach to the CloudFront distribution.<br/>Provides DDoS protection and rate limiting for the redirect service.<br/><br/>Leave null (default) for most use cases. Consider enabling if:<br/>- You have compliance requirements for WAF on all resources<br/>- You're experiencing abuse or high request volumes<br/>- You need IP-based access controls<br/><br/>Note: AWS WAF incurs additional costs per web ACL and per million requests. | `string` | `null` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Route53 hosted zone ID where DNS records will be created | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acm_certificate_arn"></a> [acm\_certificate\_arn](#output\_acm\_certificate\_arn) | The ARN of the ACM certificate used by CloudFront (provisioned in us-east-1) |
| <a name="output_caa_records"></a> [caa\_records](#output\_caa\_records) | Map of CAA records created for redirect domains (key: domain name, value: record details) |
| <a name="output_cloudfront_distribution_arn"></a> [cloudfront\_distribution\_arn](#output\_cloudfront\_distribution\_arn) | The ARN (Amazon Resource Name) for the CloudFront distribution |
| <a name="output_cloudfront_distribution_id"></a> [cloudfront\_distribution\_id](#output\_cloudfront\_distribution\_id) | The identifier for the CloudFront distribution |
| <a name="output_cloudfront_domain_name"></a> [cloudfront\_domain\_name](#output\_cloudfront\_domain\_name) | The domain name corresponding to the CloudFront distribution (e.g., d111111abcdef8.cloudfront.net) |
| <a name="output_cloudfront_logs_bucket_arn"></a> [cloudfront\_logs\_bucket\_arn](#output\_cloudfront\_logs\_bucket\_arn) | ARN of the S3 bucket for CloudFront access logs (null if logging disabled) |
| <a name="output_cloudfront_logs_bucket_name"></a> [cloudfront\_logs\_bucket\_name](#output\_cloudfront\_logs\_bucket\_name) | Name of the S3 bucket for CloudFront access logs (null if logging disabled) |
| <a name="output_dns_a_records"></a> [dns\_a\_records](#output\_dns\_a\_records) | Map of A records created for redirect domains (key: domain name, value: record details) |
| <a name="output_dns_aaaa_records"></a> [dns\_aaaa\_records](#output\_dns\_aaaa\_records) | Map of AAAA records created for redirect domains (key: domain name, value: record details) |
| <a name="output_redirect_domains"></a> [redirect\_domains](#output\_redirect\_domains) | List of fully qualified domain names that redirect to the target (computed from redirect\_hostnames and zone) |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | The ARN of the S3 bucket used as the redirect origin |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | The name of the S3 bucket used as the redirect origin |
<!-- END_TF_DOCS -->

## Examples

Working examples are available in the [`examples/`](examples/) directory:

- [Basic Redirect](examples/basic/) - Simple domain redirect
- [Path Redirect](examples/with-path/) - Redirect to a specific path
- [Minimal Cost](examples/minimal-cost/) - Lowest cost configuration

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.
