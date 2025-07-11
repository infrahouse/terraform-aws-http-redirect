resource "aws_s3_bucket" "redirect" {
  bucket_prefix = "http-redirect-"
  force_destroy = true
  tags          = local.default_module_tags
}

resource "aws_s3_bucket_website_configuration" "redirect" {
  bucket = aws_s3_bucket.redirect.bucket
  redirect_all_requests_to {
    host_name = var.redirect_to
    protocol  = "https"
  }
}

resource "aws_s3_bucket_public_access_block" "redirect" {
  bucket                  = aws_s3_bucket.redirect.bucket
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
