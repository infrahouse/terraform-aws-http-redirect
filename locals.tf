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
}
