terraform {
  //noinspection HILUnresolvedReference
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.62, < 7.0"
      configuration_aliases = [aws.us-east-1]
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}
