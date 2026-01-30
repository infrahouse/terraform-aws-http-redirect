data "aws_route53_zone" "test" {
  zone_id = var.zone_id
}

locals {
  # Apex domain (empty hostname prefix)
  test_domain = data.aws_route53_zone.test.name
}

# ==============================================================================
# Simulate "external" module creating certificate and DNS records
# (This is what terraform-aws-ecs/website-pod would do)
#
# ACM generates deterministic validation records per domain per AWS account,
# regardless of region. Both modules get the SAME validation CNAME name and value,
# causing a conflict when both try to create the record.
# ==============================================================================

resource "aws_acm_certificate" "external" {
  # Uses default provider (user's region) - simulates ECS/website-pod behavior
  domain_name       = local.test_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name    = "external-cert-${local.test_domain}"
    purpose = "Simulate external module certificate"
  }
}

resource "aws_route53_record" "external_validation" {
  for_each = {
    for dvo in aws_acm_certificate.external.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 300
}

resource "aws_route53_record" "external_caa" {
  zone_id = var.zone_id
  name    = local.test_domain
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"amazon.com\"",
    "0 issuewild \";\""
  ]
}

resource "aws_acm_certificate_validation" "external" {
  # Same region as the certificate (default provider)
  certificate_arn         = aws_acm_certificate.external.arn
  validation_record_fqdns = [for r in aws_route53_record.external_validation : r.fqdn]
}
