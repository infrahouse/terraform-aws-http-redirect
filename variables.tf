variable "redirect_hostnames" {
  description = <<-EOT
    List of hostname prefixes to redirect (e.g., ['', 'www'] for apex and www
    subdomain). Use empty string for apex domain.
  EOT
  type        = list(string)
  default     = ["", "www"]

  validation {
    condition = alltrue([
      for hostname in var.redirect_hostnames :
      can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?)?$", hostname))
    ])
    error_message = <<-EOT
      Hostname prefixes must contain only lowercase letters, numbers, and
      hyphens. They cannot contain dots (provide prefixes, not FQDNs).
    EOT
  }

  validation {
    condition     = length(var.redirect_hostnames) > 0
    error_message = "At least one hostname must be provided."
  }
}

variable "redirect_to" {
  description = <<-EOT
    Target hostname where HTTP(S) requests will be redirected (e.g.,
    'example.com'). Do not include protocol (https://).
  EOT
  type        = string

  validation {
    condition = can(regex(
      "^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$",
      var.redirect_to
    ))
    error_message = <<-EOT
      redirect_to must be a valid hostname (not a URL). Example: 'example.com'
      not 'https://example.com'
    EOT
  }
}

variable "zone_id" {
  description = "Route53 hosted zone ID where DNS records will be created"
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.zone_id))
    error_message = <<-EOT
      zone_id must be a valid Route53 zone ID (starts with Z followed by
      alphanumeric characters).
    EOT
  }
}
