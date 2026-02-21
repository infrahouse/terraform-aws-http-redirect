locals {
  module_version = "2.0.0"

  default_module_tags = merge(
    {
      created_by_module : "infrahouse/http-redirect/aws"
    }
  )

  # Parse redirect_to into components for routing rule
  # Format: "hostname[/path][?query]"
  redirect_parts = regex("^(?P<hostname>[^/?]+)(?P<path>/[^?]*)?(?P<query>\\?.*)?$", var.redirect_to)

  redirect_hostname = local.redirect_parts.hostname
  redirect_path     = try(local.redirect_parts.path, "")
  redirect_query    = try(local.redirect_parts.query, "")

  # Construct fully qualified domain names from redirect_hostnames
  # Reduces code duplication across acm.tf, dns.tf, main.tf, and outputs.tf
  redirect_domains = [
    for record in var.redirect_hostnames :
    trimprefix(join(".", [record, data.aws_route53_zone.redirect.name]), ".")
  ]

  # Map version for for_each usage in DNS records
  # Key is the hostname prefix, value is the fully qualified domain name
  redirect_domains_map = {
    for record in var.redirect_hostnames :
    record => trimprefix(join(".", [record, data.aws_route53_zone.redirect.name]), ".")
  }

  # Whether to deploy a CloudFront Function for redirect handling.
  # Required when non-GET methods are enabled or custom response headers are set,
  # because S3 website hosting cannot handle either of those.
  use_cloudfront_function = var.allow_non_get_methods || length(var.response_headers) > 0

  # CloudFront logging bucket domain name (for logging_config)
  # Format: bucket-name.s3.amazonaws.com
  cloudfront_logging_bucket = (
    var.create_logging_bucket ?
    module.cloudfront_logs_bucket[0].bucket_domain_name :
    null
  )
}
