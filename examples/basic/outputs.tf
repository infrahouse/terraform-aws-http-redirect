output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.http-redirect.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name"
  value       = module.http-redirect.cloudfront_domain_name
}

output "redirect_domains" {
  description = "Domains being redirected"
  value       = module.http-redirect.redirect_domains
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = module.http-redirect.s3_bucket_name
}