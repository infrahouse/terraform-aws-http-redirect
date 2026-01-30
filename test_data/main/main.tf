module "test" {
  source = "./../../"
  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
  redirect_to        = var.redirect_to
  redirect_hostnames = var.redirect_hostnames
  zone_id            = var.test_zone_id

  create_certificate_dns_records = var.create_certificate_dns_records

  cloudfront_logging_bucket_force_destroy = true # Allow test cleanup
}
