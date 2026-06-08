terraform {
  # Cross-variable validation (replication_region depends on create_logging_bucket)
  # requires Terraform 1.9+.
  required_version = ">= 1.9"

  //noinspection HILUnresolvedReference
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Requires AWS provider 6+: the s3-bucket module's cross-region replication
      # provisions the replica via the per-resource region argument (a 6.x feature).
      version               = ">= 6.0, < 7.0"
      configuration_aliases = [aws.us-east-1]
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}
