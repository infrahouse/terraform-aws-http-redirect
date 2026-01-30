resource "aws_route53_record" "extra" {
  for_each = local.redirect_domains_map
  zone_id  = var.zone_id
  name     = each.value
  type     = "A"

  set_identifier = var.dns_routing_policy != "simple" ? var.dns_set_identifier : null

  dynamic "weighted_routing_policy" {
    for_each = var.dns_routing_policy == "weighted" ? [1] : []
    content {
      weight = var.dns_weight
    }
  }

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.redirect.domain_name
    zone_id                = aws_cloudfront_distribution.redirect.hosted_zone_id
  }
}

resource "aws_route53_record" "extra_aaaa" {
  for_each = local.redirect_domains_map
  zone_id  = var.zone_id
  name     = each.value
  type     = "AAAA"

  set_identifier = var.dns_routing_policy != "simple" ? var.dns_set_identifier : null

  dynamic "weighted_routing_policy" {
    for_each = var.dns_routing_policy == "weighted" ? [1] : []
    content {
      weight = var.dns_weight
    }
  }

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.redirect.domain_name
    zone_id                = aws_cloudfront_distribution.redirect.hosted_zone_id
  }
}

resource "aws_route53_record" "caa_record" {
  for_each = var.create_certificate_dns_records ? local.redirect_domains_map : {}
  zone_id  = var.zone_id
  name     = each.value
  type     = "CAA"
  ttl      = 300
  records = [
    "0 issue \"amazon.com\"",
    "0 issuewild \";\""
  ]
}
