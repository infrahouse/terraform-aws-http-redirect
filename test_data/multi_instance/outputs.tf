output "zone_name" {
  value = data.aws_route53_zone.test_zone.name
}

output "instance_1_cloudfront_distribution_id" {
  value = module.instance_1.cloudfront_distribution_id
}

output "instance_1_redirect_domains" {
  value = module.instance_1.redirect_domains
}

output "instance_2_cloudfront_distribution_id" {
  value = module.instance_2.cloudfront_distribution_id
}

output "instance_2_redirect_domains" {
  value = module.instance_2.redirect_domains
}
