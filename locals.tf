locals {
  module_version = "0.2.2"

  default_module_tags = merge(
    {
      created_by_module : "infrahouse/http-redirect/aws"
    }
  )
}
