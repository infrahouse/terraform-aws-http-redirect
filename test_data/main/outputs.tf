output "zone_name" {
  value = data.aws_route53_zone.test-zone.name
}

output "acm_certificate_arn" {
  value = module.test.acm_certificate_arn
}

output "cloudfront_distribution_id" {
  value = module.test.cloudfront_distribution_id
}
