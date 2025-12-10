provider "aws" {
  region = var.region
  dynamic "assume_role" {
    for_each = var.role_arn != null ? [1] : []
    content {
      role_arn = var.role_arn
    }
  }
  default_tags {
    tags = {
      "created_by" : "infrahouse/terraform-aws-http-redirect" # GitHub repository that created a resource
    }
  }
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
  dynamic "assume_role" {
    for_each = var.role_arn != null ? [1] : []
    content {
      role_arn = var.role_arn
    }
  }
  default_tags {
    tags = {
      "created_by" : "infrahouse/terraform-aws-http-redirect" # GitHub repository that created a resource
    }
  }
}
