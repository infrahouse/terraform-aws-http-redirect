# terraform-aws-http-redirect

This Terraform module configures an HTTP/HTTPS redirect for one or more hostnames (e.g. example.com, www.example.com) using:

* Amazon CloudFront (for TLS termination and redirection)
* Amazon S3 (for static website redirect behavior)
* ACM certificate (automatically provisioned and validated in us-east-1)
* Route 53 DNS records (to map domains to the CloudFront distribution)

**Features**

* Supports HTTPS redirect (301) to a target domain or specific path
* Redirects preserve paths and query strings
* Supports both hostname-only (`example.com`) and path redirects (`example.com/landing`)
* Automatic ACM certificate provisioning and DNS validation
* CloudFront + S3 origin architecture (cost-efficient and scalable)

**Notes**

* ACM certificates must be in us-east-1 for CloudFront — this module ensures that.
* S3 bucket names and DNS records are created based on the hostnames provided.
* Redirects use HTTP 301 (permanent redirect).
* This setup incurs very low monthly costs, ideal for simple domain forwarding.

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
  source  = "infrahouse/http-redirect/aws"
  version = "0.3.0"

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
  source  = "infrahouse/http-redirect/aws"
  version = "0.3.0"

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

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_cloudfront_cache_policy.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_cache_policy) | resource |
| [aws_cloudfront_distribution.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_route53_record.caa_record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.extra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.extra_aaaa](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_website_configuration.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_website_configuration) | resource |
| [aws_iam_policy_document.enforce_ssl_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_route53_zone.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudfront_price_class"></a> [cloudfront\_price\_class](#input\_cloudfront\_price\_class) | CloudFront distribution price class. Controls which edge locations are used<br/>and affects cost:<br/>- PriceClass\_100: US, Canada, Europe (lowest cost)<br/>- PriceClass\_200: PriceClass\_100 + Asia, Africa, Oceania, Middle East<br/>- PriceClass\_All: All edge locations (highest cost, best performance globally) | `string` | `"PriceClass_100"` | no |
| <a name="input_redirect_hostnames"></a> [redirect\_hostnames](#input\_redirect\_hostnames) | List of hostname prefixes to redirect (e.g., ['', 'www'] for apex and www<br/>subdomain). Use empty string for apex domain. | `list(string)` | <pre>[<br/>  "",<br/>  "www"<br/>]</pre> | no |
| <a name="input_redirect_to"></a> [redirect\_to](#input\_redirect\_to) | Target URL where HTTP(S) requests will be redirected. Can be:<br/>- A hostname: 'example.com'<br/>- A hostname with path: 'example.com/landing'<br/><br/>Note: Query parameters in redirect\_to are not supported due to S3 routing<br/>rule limitations. Source query parameters will be preserved in redirects.<br/>Do not include protocol (https://). | `string` | n/a | yes |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Route53 hosted zone ID where DNS records will be created | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acm_certificate_arn"></a> [acm\_certificate\_arn](#output\_acm\_certificate\_arn) | The ARN of the ACM certificate used by CloudFront (provisioned in us-east-1) |
| <a name="output_caa_records"></a> [caa\_records](#output\_caa\_records) | Map of CAA records created for redirect domains (key: domain name, value: record details) |
| <a name="output_cloudfront_distribution_arn"></a> [cloudfront\_distribution\_arn](#output\_cloudfront\_distribution\_arn) | The ARN (Amazon Resource Name) for the CloudFront distribution |
| <a name="output_cloudfront_distribution_id"></a> [cloudfront\_distribution\_id](#output\_cloudfront\_distribution\_id) | The identifier for the CloudFront distribution |
| <a name="output_cloudfront_domain_name"></a> [cloudfront\_domain\_name](#output\_cloudfront\_domain\_name) | The domain name corresponding to the CloudFront distribution (e.g., d111111abcdef8.cloudfront.net) |
| <a name="output_dns_a_records"></a> [dns\_a\_records](#output\_dns\_a\_records) | Map of A records created for redirect domains (key: domain name, value: record details) |
| <a name="output_dns_aaaa_records"></a> [dns\_aaaa\_records](#output\_dns\_aaaa\_records) | Map of AAAA records created for redirect domains (key: domain name, value: record details) |
| <a name="output_redirect_domains"></a> [redirect\_domains](#output\_redirect\_domains) | List of fully qualified domain names that redirect to the target (computed from redirect\_hostnames and zone) |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | The ARN of the S3 bucket used as the redirect origin |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | The name of the S3 bucket used as the redirect origin |
<!-- END_TF_DOCS -->
