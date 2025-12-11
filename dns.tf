resource "aws_route53_record" "extra" {
  for_each = local.redirect_domains_map
  zone_id  = var.zone_id
  name     = each.value
  type     = "A"
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
  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.redirect.domain_name
    zone_id                = aws_cloudfront_distribution.redirect.hosted_zone_id
  }
}

resource "aws_route53_record" "caa_record" {
  for_each = local.redirect_domains_map
  zone_id  = var.zone_id
  name     = each.value
  type     = "CAA"
  ttl      = 300
  records = [
    "0 issue \"amazon.com\"",
    "0 issuewild \";\""
  ]
}
