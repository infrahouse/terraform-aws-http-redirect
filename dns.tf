resource "aws_route53_record" "extra" {
  count   = length(var.redirect_hostnames)
  zone_id = var.zone_id
  name    = trimprefix(join(".", [var.redirect_hostnames[count.index], data.aws_route53_zone.redirect.name]), ".")
  type    = "A"
  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.redirect.domain_name
    zone_id                = aws_cloudfront_distribution.redirect.hosted_zone_id
  }
}

resource "aws_route53_record" "caa_record" {
  count   = length(var.redirect_hostnames)
  zone_id = var.zone_id
  name    = trimprefix(join(".", [var.redirect_hostnames[count.index], data.aws_route53_zone.redirect.name]), ".")
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"amazon.com\"",
    "0 issue \"amazontrust.com\"",
    "0 issue \"awstrust.com\"",
    "0 issue \"amazonaws.com\""
  ]
}
