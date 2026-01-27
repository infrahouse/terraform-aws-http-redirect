output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.http-redirect.cloudfront_distribution_id
}

output "redirect_domains" {
  description = "Domains being redirected"
  value       = module.http-redirect.redirect_domains
}

output "monthly_cost_estimate" {
  description = "Estimated monthly cost"
  value       = "~$1-2 for low traffic"
}