output "cloudfront_distribution_id" {
  description = "The identifier for the CloudFront distribution"
  value       = aws_cloudfront_distribution.redirect.id
}

output "cloudfront_distribution_arn" {
  description = "The ARN (Amazon Resource Name) for the CloudFront distribution"
  value       = aws_cloudfront_distribution.redirect.arn
}

output "cloudfront_domain_name" {
  description = "The domain name corresponding to the CloudFront distribution (e.g., d111111abcdef8.cloudfront.net)"
  value       = aws_cloudfront_distribution.redirect.domain_name
}

output "s3_bucket_name" {
  description = "The name of the S3 bucket used as the redirect origin"
  value       = aws_s3_bucket.redirect.id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 bucket used as the redirect origin"
  value       = aws_s3_bucket.redirect.arn
}

output "acm_certificate_arn" {
  description = "The ARN of the ACM certificate used by CloudFront (provisioned in us-east-1)"
  value       = aws_acm_certificate.redirect.arn
}

output "redirect_domains" {
  description = "List of fully qualified domain names that redirect to the target (computed from redirect_hostnames and zone)"
  value = [
    for record in var.redirect_hostnames : trimprefix(join(".", [record, data.aws_route53_zone.redirect.name]), ".")
  ]
}

output "dns_a_records" {
  description = "Map of A records created for redirect domains (key: domain name, value: record details)"
  value = {
    for idx, record in aws_route53_record.extra : record.name => {
      fqdn    = record.fqdn
      name    = record.name
      type    = record.type
      zone_id = record.zone_id
    }
  }
}

output "dns_aaaa_records" {
  description = "Map of AAAA records created for redirect domains (key: domain name, value: record details)"
  value = {
    for idx, record in aws_route53_record.extra_aaaa : record.name => {
      fqdn    = record.fqdn
      name    = record.name
      type    = record.type
      zone_id = record.zone_id
    }
  }
}

output "caa_records" {
  description = "Map of CAA records created for redirect domains (key: domain name, value: record details)"
  value = {
    for idx, record in aws_route53_record.caa_record : record.name => {
      fqdn    = record.fqdn
      name    = record.name
      type    = record.type
      zone_id = record.zone_id
      records = record.records
    }
  }
}