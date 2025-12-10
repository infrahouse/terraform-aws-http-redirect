locals {
  module_version = "0.3.0"

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
}
