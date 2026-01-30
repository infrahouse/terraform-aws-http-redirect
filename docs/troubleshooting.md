# Troubleshooting

This page covers common issues and their solutions when using the terraform-aws-http-redirect module.

## Certificate Validation Issues

### Timeout During Certificate Validation

**Error:**
```
Error waiting for ACM Certificate validation: timeout while waiting for state to become 'ISSUED'
```

**Cause:** DNS validation records are not properly created or propagated.

**Solution:**

1. Verify your Route 53 hosted zone is publicly accessible:
   ```bash
   dig NS example.com
   ```

2. Check that the returned nameservers match your Route 53 zone's NS records:
   ```bash
   aws route53 get-hosted-zone --id Z1234567890ABC --query 'DelegationSet.NameServers'
   ```

3. Verify the validation records were created:
   ```bash
   aws route53 list-resource-record-sets --hosted-zone-id Z1234567890ABC \
     --query "ResourceRecordSets[?Type=='CNAME']"
   ```

4. Wait 5-10 minutes for DNS propagation and retry:
   ```bash
   terraform apply
   ```

!!! tip
    If using a newly registered domain, DNS propagation can take up to 48 hours.

### Certificate in Wrong Region

**Error:**
```
Error: creating CloudFront Distribution: InvalidViewerCertificate:
The specified SSL certificate doesn't exist, isn't in us-east-1 region
```

**Cause:** The ACM certificate was not created in us-east-1.

**Solution:** Ensure you pass both providers to the module:

```hcl
module "http-redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.2.0"

  # ... other configuration ...

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1  # This is required!
  }
}
```

## Provider Configuration Issues

### Provider Configuration Not Present

**Error:**
```
Provider configuration not present
```

**Solution:** Define both required providers:

```hcl
provider "aws" {
  region = "us-west-2"  # Your primary region
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}
```

### Module Does Not Support Provider

**Error:**
```
Module does not support provider alias
```

**Solution:** Use the correct provider block syntax:

```hcl
module "http-redirect" {
  # ...
  providers = {
    aws           = aws           # Default provider
    aws.us-east-1 = aws.us-east-1 # Aliased provider for ACM
  }
}
```

## DNS Issues

### Redirect Not Working

**Symptoms:** Accessing the domain shows CloudFront error or times out.

**Diagnostic steps:**

1. Verify DNS records point to CloudFront:
   ```bash
   dig A www.example.com
   dig AAAA www.example.com
   ```
   Should return CloudFront domain (format: `d111111abcdef8.cloudfront.net`)

2. Check CloudFront distribution status:
   ```bash
   aws cloudfront get-distribution --id EDFDVBD6EXAMPLE \
     --query 'Distribution.Status'
   ```
   Status should be `Deployed` (initial deployment takes 15-30 minutes)

3. Test redirect manually:
   ```bash
   curl -I https://www.example.com
   ```
   Should return HTTP 301 with Location header

### DNS Records Not Created

**Symptoms:** `dig` returns NXDOMAIN or wrong records.

**Solution:**

1. Verify the zone_id is correct:
   ```bash
   aws route53 get-hosted-zone --id Z1234567890ABC
   ```

2. Check Terraform state:
   ```bash
   terraform state show 'module.http-redirect.aws_route53_record.extra["www.example.com"]'
   ```

3. Ensure the hosted zone is for the correct domain

## S3 Issues

### Bucket Already Exists

**Error:**
```
Error creating S3 bucket: BucketAlreadyExists
```

**Cause:** S3 bucket names are globally unique. The bucket name derived from your hostname
is already taken.

**Solutions:**

- If you previously created and deleted the bucket, wait 24 hours (AWS requirement)
- If another account owns the bucket, use a different hostname prefix
- Check if you have an existing bucket with the same name in another region

### Bucket Already Owned By You

**Error:**
```
Error creating S3 bucket: BucketAlreadyOwnedByYou
```

**Cause:** The bucket exists in your account, possibly from a previous deployment.

**Solutions:**

1. Import the existing bucket:
   ```bash
   terraform import 'module.http-redirect.aws_s3_bucket.redirect' bucket-name
   ```

2. Or delete the existing bucket (if empty):
   ```bash
   aws s3 rb s3://bucket-name
   ```

## CloudFront Issues

### Distribution Not Deploying

**Symptoms:** Distribution stuck in "In Progress" state for over 30 minutes.

**Solution:**

1. Check for CloudFront service issues: [AWS Service Health Dashboard](https://health.aws.amazon.com/)

2. Verify no conflicting distributions exist:
   ```bash
   aws cloudfront list-distributions \
     --query "DistributionList.Items[?contains(Aliases.Items, 'example.com')]"
   ```

3. Check CloudWatch for errors:
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/CloudFront \
     --metric-name 4xxErrorRate \
     --dimensions Name=DistributionId,Value=EDFDVBD6EXAMPLE \
     --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
     --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
     --period 300 \
     --statistics Average
   ```

### Access Denied Errors

**Symptoms:** CloudFront returns 403 Access Denied.

**Possible causes:**

1. S3 bucket policy not applied
2. CloudFront Origin Access Identity issues
3. S3 website endpoint not configured

**Diagnostic:**
```bash
# Check S3 website endpoint directly
curl -I http://bucket-name.s3-website-us-west-2.amazonaws.com
```

## Logging Issues

### Logs Not Appearing

**Symptoms:** Logging bucket is empty after redirect traffic.

**Solutions:**

1. Verify logging is enabled:
   ```bash
   terraform state show 'module.http-redirect.aws_cloudfront_distribution.redirect' \
     | grep -A5 logging_config
   ```

2. CloudFront logs are delivered with ~24 hour delay
3. Check bucket permissions allow CloudFront to write

## Verification Commands

Use these commands to verify your deployment:

```bash
# Test HTTP to HTTPS redirect
curl -I http://www.example.com

# Test HTTPS redirect to target
curl -I https://www.example.com

# Test path preservation
curl -I https://www.example.com/some/path

# Test query string preservation
curl -I "https://www.example.com/page?foo=bar&baz=qux"

# Check response headers
curl -I https://www.example.com 2>&1 | grep -i "strict-transport-security\|x-frame-options"
```

**Expected responses:**

| Request | Expected Response |
|---------|-------------------|
| HTTP request | 301 redirect to HTTPS version |
| HTTPS request | 301 redirect to target domain |
| With path | Location header preserves path |
| With query | Location header preserves query params |

## Getting Help

If you're still experiencing issues:

1. Check the [GitHub Issues](https://github.com/infrahouse/terraform-aws-http-redirect/issues)
2. Review [AWS CloudFront documentation](https://docs.aws.amazon.com/cloudfront/)
3. [Contact InfraHouse](https://infrahouse.com/contact) for professional support