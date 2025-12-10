resource "aws_acm_certificate" "redirect" {
  provider                  = aws.us-east-1
  domain_name               = local.redirect_domains[0]
  validation_method         = "DNS"
  subject_alternative_names = local.redirect_domains
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
  provider = aws.us-east-1
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
  provider        = aws.us-east-1
  certificate_arn = aws_acm_certificate.redirect.arn
  validation_record_fqdns = [
    for d in aws_route53_record.cert_validation : d.fqdn
  ]
}
