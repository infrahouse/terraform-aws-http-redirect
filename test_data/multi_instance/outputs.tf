output "zone_name" {
  description = "Route53 zone name used for test DNS records"
  value       = data.aws_route53_zone.test_zone.name
}

output "instance_1_cloudfront_distribution_id" {
  description = "CloudFront distribution ID for first redirect instance"
  value       = module.instance_1.cloudfront_distribution_id
}

output "instance_1_redirect_domains" {
  description = "Redirect domain names for first redirect instance"
  value       = module.instance_1.redirect_domains
}

output "instance_2_cloudfront_distribution_id" {
  description = "CloudFront distribution ID for second redirect instance"
  value       = module.instance_2.cloudfront_distribution_id
}

output "instance_2_redirect_domains" {
  description = "Redirect domain names for second redirect instance"
  value       = module.instance_2.redirect_domains
}
