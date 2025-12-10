# terraform-aws-http-redirect

This Terraform module configures an HTTP/HTTPS redirect for one or more hostnames (e.g. example.com, www.example.com) using:

* Amazon CloudFront (for TLS termination and redirection)
* Amazon S3 (for static website redirect behavior)
* ACM certificate (automatically provisioned and validated in us-east-1)
* Route 53 DNS records (to map domains to the CloudFront distribution)

**Features**
 
* Supports HTTPS redirect (301) to a target domain
* Redirects preserve paths and query strings
* Automatic ACM certificate provisioning and DNS validation
* CloudFront + S3 origin architecture (cost-efficient and scalable)

**Notes**

* ACM certificates must be in us-east-1 for CloudFront — this module ensures that.
* S3 bucket names and DNS records are created based on the hostnames provided.
* Redirects use HTTP 301 (permanent redirect).
* This setup incurs very low monthly costs, ideal for simple domain forwarding.

## Usage

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
> Make sure the hosted zone for example.com exists in Route 53.

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.62, < 7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.62, < 7.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_cloudfront_distribution.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_route53_record.caa_record](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.extra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_website_configuration.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_website_configuration) | resource |
| [aws_iam_policy_document.enforce_ssl_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_route53_zone.redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_redirect_hostnames"></a> [redirect\_hostnames](#input\_redirect\_hostnames) | Name of application | `list(string)` | <pre>[<br/>  "",<br/>  "www"<br/>]</pre> | no |
| <a name="input_redirect_to"></a> [redirect\_to](#input\_redirect\_to) | Hostname where to redirect HTTP(S) requests to | `string` | n/a | yes |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Zone ID where the redirect\_hostnames records will be created | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
