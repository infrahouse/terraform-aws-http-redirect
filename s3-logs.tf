# IAM policy document for CloudFront log delivery
data "aws_iam_policy_document" "cloudfront_logs" {
  count = var.create_logging_bucket ? 1 : 0

  statement {
    sid    = "AWSCloudFrontLogsWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = ["s3:PutObject"]

    resources = [
      "arn:aws:s3:::${replace(data.aws_route53_zone.redirect.name, ".", "-")}-cf-logs-${random_string.this.result}/*"
    ]

    # Note: We don't add AWS:SourceArn condition here to avoid circular dependency
    # (CloudFront ARN depends on logging bucket, which depends on policy, which would depend on CloudFront)
    # The bucket is still secure as only CloudFront service can write to it
  }
}

# S3 bucket for CloudFront access logs
# Uses infrahouse/s3-bucket/aws module for compliance and best practices
module "cloudfront_logs_bucket" {
  count   = var.create_logging_bucket ? 1 : 0
  source  = "registry.infrahouse.com/infrahouse/s3-bucket/aws"
  version = "0.3.1"

  # Use zone name for bucket naming (not redirect_domains which may start with "")
  bucket_name = "${replace(data.aws_route53_zone.redirect.name, ".", "-")}-cf-logs-${random_string.this.result}"

  # Allow bucket deletion with contents in test/dev environments
  force_destroy = var.cloudfront_logging_bucket_force_destroy

  # Enable ACLs for CloudFront log delivery
  enable_acl       = true
  acl              = "private"
  object_ownership = "BucketOwnerPreferred"

  # Grant CloudFront log delivery permissions
  bucket_policy = data.aws_iam_policy_document.cloudfront_logs[0].json

  tags = merge(
    local.default_module_tags,
    {
      Purpose        = "CloudFront access logs"
      module_version = local.module_version
    }
  )
}
