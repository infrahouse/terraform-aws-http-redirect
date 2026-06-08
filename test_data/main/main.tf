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
  allow_non_get_methods          = var.allow_non_get_methods
  permanent_redirect             = var.permanent_redirect
  response_headers               = var.response_headers

  cloudfront_logging_bucket_force_destroy = true # Allow test cleanup

  # Exercise cross-region replication end to end. The replica must live in a
  # different region than the log bucket, so derive it from the deploy region.
  replication_region = var.region == "us-east-1" ? "us-west-2" : "us-east-1"
}
