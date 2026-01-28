# Getting Started

This guide walks you through deploying your first HTTP redirect using the terraform-aws-http-redirect module.

## Prerequisites

Before you begin, ensure you have:

1. **Terraform** (>= 1.0) installed
2. **AWS CLI** configured with appropriate credentials
3. **Route 53 Hosted Zone** for your domain (publicly accessible)
4. **IAM Permissions** for CloudFront, S3, ACM, and Route 53

### Required IAM Permissions

Your AWS credentials need permissions for:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudfront:*",
        "s3:*",
        "acm:*",
        "route53:*"
      ],
      "Resource": "*"
    }
  ]
}
```

!!! note
    For production, scope these permissions more narrowly based on your security requirements.

## Step 1: Configure Providers

This module requires **two AWS providers** because CloudFront requires ACM certificates
to be in the `us-east-1` region.

Create a `providers.tf` file:

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.62, < 7.0"
    }
  }
}

# Primary provider - your main region
provider "aws" {
  region = "us-west-2"  # Change to your preferred region
}

# Required for ACM certificates (CloudFront requirement)
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}
```

## Step 2: Create the Module Configuration

Create a `main.tf` file:

```hcl
# Look up your existing Route 53 hosted zone
data "aws_route53_zone" "redirect" {
  name = "example.com"  # Replace with your domain
}

# Create the redirect
module "http-redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.1.0"

  # Hostnames to redirect (empty string = apex domain)
  redirect_hostnames = ["", "www"]

  # Target domain (without https://)
  redirect_to = "target.com"

  # Route 53 zone for DNS records
  zone_id = data.aws_route53_zone.redirect.zone_id

  # Pass both providers to the module
  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

## Step 3: Create Outputs (Optional)

Create an `outputs.tf` file to see deployment details:

```hcl
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.http-redirect.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name"
  value       = module.http-redirect.cloudfront_domain_name
}

output "redirect_domains" {
  description = "Domains being redirected"
  value       = module.http-redirect.redirect_domains
}
```

## Step 4: Deploy

Initialize and apply:

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply
```

!!! warning "Deployment Time"
    Initial deployment takes **15-30 minutes** due to:

    - ACM certificate validation (~5 minutes)
    - CloudFront distribution deployment (~15-20 minutes)

## Step 5: Verify

After deployment completes, verify the redirect works:

```bash
# Test HTTPS redirect
curl -I https://example.com

# Expected response:
# HTTP/2 301
# location: https://target.com/

# Test path preservation
curl -I https://example.com/page?query=1

# Expected response:
# HTTP/2 301
# location: https://target.com/page?query=1
```

## Common Deployment Issues

### Certificate Validation Timeout

If certificate validation times out:

1. Verify your Route 53 zone is publicly accessible:
   ```bash
   dig NS example.com
   ```

2. Check that the returned nameservers match your Route 53 zone

3. Wait 5-10 minutes for DNS propagation and retry

### Provider Configuration Error

Ensure you pass both providers to the module:

```hcl
module "http-redirect" {
  # ...
  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

## Next Steps

- [Configuration](configuration.md) - Customize logging, pricing, and security options
- [Examples](examples.md) - See more use cases
- [Architecture](architecture.md) - Understand how the module works