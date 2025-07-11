resource "aws_acm_certificate" "redirect" {
  domain_name       = trimprefix(join(".", [var.redirect_hostnames[0], data.aws_route53_zone.redirect.name]), ".")
  validation_method = "DNS"
  subject_alternative_names = [
    for record in var.redirect_hostnames : trimprefix(join(".", [record, data.aws_route53_zone.redirect.name]), ".")
  ]
  lifecycle {
    create_before_destroy = true
  }
  tags = merge(
    local.default_module_tags,
    {
      VantaContainsUserData : false
      VantaContainsEPHI : false
    }
  )
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.redirect.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [
    each.value.record
  ]
  ttl = 60
}

resource "aws_acm_certificate_validation" "redirect" {
  certificate_arn = aws_acm_certificate.redirect.arn
  validation_record_fqdns = [
    for d in aws_route53_record.cert_validation : d.fqdn
  ]
}
