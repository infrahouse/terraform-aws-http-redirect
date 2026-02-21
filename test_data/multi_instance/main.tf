module "instance_1" {
  source = "./../../"
  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
  redirect_to        = var.redirect_to_1
  redirect_hostnames = var.redirect_hostnames_1
  zone_id            = var.test_zone_id

  cloudfront_logging_bucket_force_destroy = true # Allow test cleanup
}

module "instance_2" {
  source = "./../../"
  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
  redirect_to        = var.redirect_to_2
  redirect_hostnames = var.redirect_hostnames_2
  zone_id            = var.test_zone_id

  cloudfront_logging_bucket_force_destroy = true # Allow test cleanup
}
