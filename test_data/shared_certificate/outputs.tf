output "external_certificate_arn" {
  description = "ACM certificate ARN from external (simulated) module"
  value       = aws_acm_certificate.external.arn
}

output "test_domain" {
  description = "The test domain"
  value       = local.test_domain
}