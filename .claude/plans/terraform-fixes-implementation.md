# Terraform AWS HTTP Redirect Module - Implementation Plan

**Created:** 2025-12-10
**Based on:** `.claude/reviews/terraform-module-review.md`
**Target Version:** 1.0.0 (Single Breaking Release)

---

## Progress Tracker

### Phase 1: Critical Fixes - BLOCKING ISSUES

- [x] 1.1 Fix Missing us-east-1 Provider Alias [CRITICAL]
- [x] 1.2 Add AAAA Records for IPv6 Support
- [x] 1.3 Add Module Outputs (outputs.tf)
- [x] 1.4 Add Input Validation to variables.tf
- [x] 1.5 Fix Variable Description for redirect_hostnames

### Phase 2: Important Improvements

- [x] 2.1 Add Support for URL Path Redirects
- [x] 2.2 Replace Deprecated CloudFront forwarded_values with Cache Policies
- [x] 2.3 Extract Hostname Logic to locals.tf (Reduce Duplication)
- [x] 2.4 Convert count to for_each for DNS Records
- [x] 2.5 Add CloudFront Price Class Variable

### Phase 3: Security Enhancements

- [x] 3.1 Add S3 Bucket Encryption
- [~] 3.2 Make CAA Records Optional (SKIPPED - solves non-problem)
- [x] 3.3 Add CloudFront Logging with infrahouse/s3-bucket module
- [x] 3.4 Add Optional WAF Integration

### Phase 4: Nice-to-Have Enhancements

- [ ] 4.1 Add Security Headers Policy
- [ ] 4.3 Add Complete Tagging to All Resources
- [ ] 4.4 Increase ACM Validation TTL from 60 to 300

### Phase 5: Testing Improvements

- [ ] 5.1 Add Multi-Region Test (us-west-2 + us-east-1)
- [ ] 5.2 Add Query String Preservation Test
- [ ] 5.3 Add Path Preservation Test
- [ ] 5.4 Add Idempotency Test

### Phase 6: Documentation Updates

- [ ] 6.1 Update README with Provider Configuration [CRITICAL]
- [ ] 6.2 Add Cost Documentation
- [ ] 6.3 Add Troubleshooting Guide
- [ ] 6.4 Add Architecture Diagram

**Progress:** 13/25 tasks completed

---

## Overview

This implementation plan addresses all issues identified in the comprehensive
module review. Issues are organized by priority and grouped into logical
phases for incremental delivery.

---

## Phase 1: Critical Fixes - BLOCKING ISSUES

These issues prevent the module from working correctly and must be fixed
immediately.

### 1.1 Fix Missing us-east-1 Provider Alias [CRITICAL]

**Issue:** Module fails when used from any region other than us-east-1
**Impact:** Blocks ~90% of potential users
**Files to modify:** `terraform.tf`, `acm.tf`

**Implementation Steps:**

1. Update `terraform.tf`:
   - Add `configuration_aliases = [aws.us-east-1]` to the AWS provider config
   - Keep existing version constraint `~> 5.62`

2. Update `acm.tf` resources to use us-east-1 provider:
   - Add `provider = aws.us-east-1` to `aws_acm_certificate.redirect`
   - Add `provider = aws.us-east-1` to `aws_route53_record.cert_validation`
   - Add `provider = aws.us-east-1` to
     `aws_acm_certificate_validation.redirect`

3. Update README.md with usage example showing provider configuration:
   - Add section explaining the us-east-1 requirement
   - Show example with primary region (e.g., eu-west-1) and us-east-1 alias
   - Explain WHY this is required (CloudFront certificate requirement)

4. Update `test_data/main/providers.tf`:
   - Add us-east-1 provider alias
   - Pass provider to module invocation

**Testing:**
- Run tests from us-east-1 (should still work)
- Run tests from us-west-2 (should now work)
- Verify ACM certificate is always created in us-east-1 regardless of
  deployment region

**Expected Changes:**
```hcl
# terraform.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.62"
      configuration_aliases = [aws.us-east-1]
    }
  }
}

# acm.tf (add to each resource)
provider = aws.us-east-1

# README.md (add example)
providers = {
  aws.us-east-1 = aws.us-east-1
}
```

---

### 1.2 Add AAAA Records for IPv6 Support [HIGH]

**Issue:** CloudFront has IPv6 enabled but no AAAA DNS records exist
**Impact:** IPv6-only users cannot access redirect domains
**Files to modify:** `dns.tf`

**Implementation Steps:**
1. Add new resource in `dns.tf` for AAAA records
2. Mirror the structure of existing A records (`aws_route53_record.extra`)
3. Use same hostname construction logic
4. Point to same CloudFront distribution

**Expected Changes:**
```hcl
# dns.tf - Add after aws_route53_record.extra
resource "aws_route53_record" "extra_aaaa" {
  count   = length(var.redirect_hostnames)
  zone_id = var.zone_id
  name    = trimprefix(
    join(".", [
      var.redirect_hostnames[count.index],
      data.aws_route53_zone.redirect.name
    ]),
    "."
  )
  type    = "AAAA"

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.redirect.domain_name
    zone_id                = aws_cloudfront_distribution.redirect.hosted_zone_id
  }
}
```

**Testing:**
- Verify AAAA records are created
- Test IPv6 connectivity if possible (may require IPv6-enabled environment)
- Verify both A and AAAA records point to same CloudFront distribution

---

### 1.3 Add Module Outputs [HIGH]

**Issue:** No outputs file exists - users cannot reference created resources
**Impact:** Poor developer experience, can't chain modules
**Files to create:** `outputs.tf`

**Implementation Steps:**
1. Create new `outputs.tf` file
2. Add outputs for:
   - CloudFront distribution ID, ARN, domain name
   - S3 bucket name
   - ACM certificate ARN
   - Redirect domains (computed list)
   - DNS records map

**Expected Changes:**
```hcl
# outputs.tf (new file)
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.redirect.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.redirect.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.redirect.domain_name
}

output "s3_bucket_name" {
  description = "S3 bucket name used for redirect origin"
  value       = aws_s3_bucket.redirect.id
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.redirect.arn
}

output "redirect_domains" {
  description = "List of fully qualified domain names configured for redirect"
  value = [
    for record in var.redirect_hostnames :
      trimprefix(
        join(".", [record, data.aws_route53_zone.redirect.name]),
        "."
      )
  ]
}

output "dns_records" {
  description = "Map of created DNS records (A and AAAA)"
  value = {
    a_records = {
      for idx, record in aws_route53_record.extra :
        record.name => record.fqdn
    }
    aaaa_records = {
      for idx, record in aws_route53_record.extra_aaaa :
        record.name => record.fqdn
    }
  }
}
```

**Testing:**
- Run `terraform output` after apply
- Verify all outputs contain expected values
- Update test to validate output values

---

### 1.4 Add Input Validation [HIGH]

**Issue:** Variables lack validation - errors occur at runtime instead of plan
time
**Impact:** Poor user experience, unclear error messages
**Files to modify:** `variables.tf`

**Implementation Steps:**
1. Add validation block to `redirect_hostnames`:
   - Ensure non-empty list
   - Validate hostname format (lowercase, no dots, no invalid characters)
   - Add helpful error messages

2. Add validation block to `redirect_to`:
   - Validate hostname format
   - Prevent common mistakes (URLs instead of hostnames)

3. Add validation block to `zone_id`:
   - Validate Route53 zone ID format (starts with Z)

**Expected Changes:**
```hcl
# variables.tf
variable "redirect_hostnames" {
  description = <<-EOT
    List of hostname prefixes to redirect (e.g., ['', 'www'] for apex and www
    subdomain). Use empty string for apex domain.
  EOT
  type        = list(string)
  default     = ["", "www"]

  validation {
    condition = alltrue([
      for hostname in var.redirect_hostnames :
        can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?)?$", hostname))
    ])
    error_message = <<-EOT
      Hostname prefixes must contain only lowercase letters, numbers, and
      hyphens. They cannot contain dots (provide prefixes, not FQDNs).
    EOT
  }

  validation {
    condition     = length(var.redirect_hostnames) > 0
    error_message = "At least one hostname must be provided."
  }
}

variable "redirect_to" {
  description = <<-EOT
    Target hostname where HTTP(S) requests will be redirected (e.g.,
    'example.com')
  EOT
  type        = string

  validation {
    condition = can(regex(
      "^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$",
      var.redirect_to
    ))
    error_message = <<-EOT
      redirect_to must be a valid hostname (not a URL). Example: 'example.com'
      not 'https://example.com'
    EOT
  }
}

variable "zone_id" {
  description = "Route53 hosted zone ID where DNS records will be created"
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.zone_id))
    error_message = <<-EOT
      zone_id must be a valid Route53 zone ID (starts with Z followed by
      alphanumeric characters).
    EOT
  }
}
```

**Testing:**
- Test with invalid hostname (uppercase, dots, special chars)
- Test with empty hostname list
- Test with invalid zone_id
- Test with URL instead of hostname for redirect_to
- Verify error messages are clear and helpful

---

### 1.5 Fix Variable Description [MEDIUM]

**Issue:** `redirect_hostnames` description says "Name of application" which
is misleading
**Impact:** User confusion
**Files to modify:** `variables.tf`

**Implementation Steps:**
1. Update description to accurately describe what the variable does
2. Include examples in the description

**Expected Changes:**
```hcl
variable "redirect_hostnames" {
  description = <<-EOT
    List of hostname prefixes to redirect (e.g., ['', 'www'] for apex and www
    subdomain). Use empty string for apex domain.
  EOT
  type        = list(string)
  default     = ["", "www"]
}
```

---

## Phase 2: Important Improvements

These improvements enhance functionality, maintainability, and future-proofing.

### 2.1 Add Support for URL Path Redirects [HIGH]

**Issue:** Module only supports hostname-level redirects (e.g., foo.com →
bar.com), not URL redirects (e.g., foo.com → bar.com/path)
**Impact:** Limited functionality, can't redirect to specific paths
**Requested by:** User feedback
**Files to modify:** `variables.tf`, `s3.tf`

**Current Limitation:**
The S3 bucket website configuration uses `redirect_all_requests_to` which only
accepts a hostname:
```hcl
redirect_all_requests_to {
  host_name = var.redirect_to  # Only hostname, no path
  protocol  = "https"
}
```

**Implementation Approach:**

Switch from `redirect_all_requests_to` to `routing_rule` which supports full
URL redirects.

**Pros:**
- More flexible, supports both hostname-only and full URL redirects
- Single variable can handle both use cases
- S3 native functionality
- Backward compatible with existing hostname-only usage

**Cons:**
- Slightly more complex configuration internally
- Uses S3 routing rules instead of simple redirect_all_requests_to

**Implementation Details:**

**Usage Examples (to be added to README):**

```hcl
# Example 1: Simple hostname redirect (current behavior)
# foo.com → bar.com (preserves paths and query strings)
module "redirect" {
  source  = "infrahouse/http-redirect/aws"
  version = "0.5.0"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  redirect_to        = "bar.com"
  redirect_hostnames = ["", "www"]
  zone_id            = aws_route53_zone.foo.zone_id
}
# Result: https://foo.com/any/path?query=1 → https://bar.com/any/path?query=1

# Example 2: Redirect to specific path (path preservation)
# foo.com → bar.com/landing-page (appends original path)
module "redirect" {
  source  = "infrahouse/http-redirect/aws"
  version = "0.5.0"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  redirect_to        = "bar.com/landing-page"
  redirect_hostnames = ["", "www"]
  zone_id            = aws_route53_zone.foo.zone_id
}
# Result: https://foo.com/anything → https://bar.com/landing-page/anything

# Example 3: Fixed destination (no path preservation)
# All foo.com/* → bar.com/welcome
module "redirect" {
  source  = "infrahouse/http-redirect/aws"
  version = "0.5.0"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  redirect_to        = "bar.com/welcome"
  redirect_hostnames = ["", "www"]
  zone_id            = aws_route53_zone.foo.zone_id
  preserve_path      = false
}
# Result: https://foo.com/anything → https://bar.com/welcome

# Example 4: HTTP protocol (edge case)
module "redirect" {
  source  = "infrahouse/http-redirect/aws"
  version = "0.5.0"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  redirect_to        = "bar.com"
  redirect_protocol  = "http"
  redirect_hostnames = ["", "www"]
  zone_id            = aws_route53_zone.foo.zone_id
}
# Result: https://foo.com/page → http://bar.com/page

# Example 5: Multiple subdomains to one target
# old.example.com + legacy.example.com → new.example.com/docs
module "redirect" {
  source  = "infrahouse/http-redirect/aws"
  version = "0.5.0"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  redirect_to        = "new.example.com/docs"
  redirect_hostnames = ["old", "legacy"]
  zone_id            = aws_route53_zone.example.zone_id
}
# Result: https://old.example.com/guide → https://new.example.com/docs/guide

# Example 6: Same provider for both (managing everything from us-east-1)
module "redirect" {
  source  = "infrahouse/http-redirect/aws"
  version = "0.5.0"

  providers = {
    aws           = aws.us-east-1
    aws.us-east-1 = aws.us-east-1  # Same provider
  }

  redirect_to = "tinyfish.ai"
  zone_id     = aws_route53_zone.tinyfish_io.zone_id
}
```

**Behavior Comparison Table:**

| Scenario | Current Module | New (preserve_path=true) | New (preserve_path=false) |
|----------|----------------|--------------------------|---------------------------|
| `redirect_to = "bar.com"` | `foo.com/x` → `bar.com/x` | `foo.com/x` → `bar.com/x` | `foo.com/x` → `bar.com` |
| `redirect_to = "bar.com/base"` | ❌ Not supported | `foo.com/x` → `bar.com/base/x` | `foo.com/x` → `bar.com/base` |
| `redirect_to = "bar.com/page.html"` | ❌ Not supported | `foo.com/x` → `bar.com/page.html/x` ⚠️ | `foo.com/x` → `bar.com/page.html` ✓ |

**Step 1: Update variables.tf**
```hcl
variable "redirect_to" {
  description = <<-EOT
    Target URL or hostname where HTTP(S) requests will be redirected. Can be
    a hostname (e.g., 'example.com') or full URL (e.g., 'example.com/path').
    Protocol (https://) should not be included.
  EOT
  type        = string

  validation {
    condition = can(regex(
      "^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*(/.*)?$",
      var.redirect_to
    ))
    error_message = <<-EOT
      redirect_to must be a valid hostname or hostname with path. Examples:
      'example.com' or 'example.com/foo/bar'. Do not include protocol
      (https://).
    EOT
  }
}

variable "redirect_protocol" {
  description = "Protocol to use for redirects (http or https)"
  type        = string
  default     = "https"

  validation {
    condition     = contains(["http", "https"], var.redirect_protocol)
    error_message = "redirect_protocol must be either 'http' or 'https'."
  }
}
```

**Step 2: Update s3.tf to use routing rules**
```hcl
# locals.tf - Add helper to parse redirect_to
locals {
  module_version = "0.3.0"

  # Parse redirect_to into hostname and path components
  redirect_parts    = split("/", var.redirect_to)
  redirect_hostname = local.redirect_parts[0]
  redirect_path = length(local.redirect_parts) > 1 ? (
    "/${join("/", slice(local.redirect_parts, 1, length(local.redirect_parts)))}"
  ) : ""

  redirect_domains = [
    for record in var.redirect_hostnames :
      trimprefix(
        join(".", [record, data.aws_route53_zone.redirect.name]),
        "."
      )
  ]

  default_module_tags = {
    created_by_module = "infrahouse/http-redirect/aws"
  }
}

# s3.tf - Replace redirect_all_requests_to with routing_rule
resource "aws_s3_bucket_website_configuration" "redirect" {
  bucket = aws_s3_bucket.redirect.bucket

  # Use routing_rule instead of redirect_all_requests_to for path support
  routing_rule {
    redirect {
      host_name = local.redirect_hostname
      protocol  = var.redirect_protocol
      # Control path behavior with preserve_path variable
      replace_key_prefix_with = (
        var.preserve_path && local.redirect_path != "" ?
          local.redirect_path : null
      )
      replace_key_with = (
        !var.preserve_path && local.redirect_path != "" ?
          local.redirect_path : null
      )
      http_redirect_code = "301"
    }
  }
}
```

**Step 3: Update variable description fix in Phase 1**

Make sure the updated description from Phase 1.4 matches this new
functionality.

**Testing Requirements:**

1. Test hostname-only redirect: `redirect_to = "bar.com"`
   - Verify: `https://foo.com/any/path` → `https://bar.com/any/path` (path
     preserved)

2. Test hostname with path: `redirect_to = "bar.com/base"`
   - Verify: `https://foo.com/any/path` → `https://bar.com/base/any/path`
     (path prepended)

3. Test hostname with path (no original path preservation):
   `redirect_to = "bar.com/specific-page"`
   - Verify: `https://foo.com/any/path` → `https://bar.com/specific-page`
     (fixed destination)

4. Test with query strings preserved

5. Test HTTP protocol option: `redirect_protocol = "http"`

**Documentation Updates:**
- Update README.md with examples of both use cases:
  - Simple hostname redirect: `redirect_to = "example.com"`
  - Path redirect: `redirect_to = "example.com/landing-page"`
- Document path preservation behavior
- Add examples in EXAMPLES.md or similar

**Backward Compatibility:**

This change is **BACKWARD COMPATIBLE** if:
- Existing users only provide hostname (no path)
- S3 routing rules behave identically to redirect_all_requests_to for
  hostname-only redirects

**Important Note:**

S3 routing rules have specific behavior:
- `replace_key_with` = replace entire path with fixed value
- `replace_key_prefix_with` = prepend value to original path
- If neither specified, preserves original path

We need to decide on the desired behavior. Recommended options:

**Option 1: Always preserve path (append to redirect target)**
- `foo.com/page` + `redirect_to = "bar.com"` → `bar.com/page` ✓ Current
  behavior
- `foo.com/page` + `redirect_to = "bar.com/base"` → `bar.com/base/page` ✓
  Path added

**Option 2: Use redirect path as replacement**
- `foo.com/page` + `redirect_to = "bar.com"` → `bar.com/page` ✓ Current
  behavior
- `foo.com/page` + `redirect_to = "bar.com/base"` → `bar.com/base` ✓ Fixed
  destination

**Recommendation:** Implement Option 1 (path preservation) as default, add
optional variable to control behavior.

**Add to variables.tf:**
```hcl
variable "preserve_path" {
  description = <<-EOT
    Whether to preserve the request path when redirecting. If true,
    'foo.com/page' redirects to 'redirect_to/page'. If false, all requests go
    to exact redirect_to URL.
  EOT
  type        = bool
  default     = true
}
```

This allows both use cases:
- `preserve_path = true` (default): `foo.com/anything` →
  `bar.com/base/anything`
- `preserve_path = false`: `foo.com/anything` → `bar.com/base`

---

### 2.2 Replace Deprecated CloudFront Configuration [HIGH]

**Issue:** Using deprecated `forwarded_values` block instead of cache policies
**Impact:** AWS will eventually remove support; migration will be required
**Files to modify:** `main.tf`, create new cache policy resource

**Implementation Steps:**
1. Create new `aws_cloudfront_cache_policy` resource
2. Configure cache policy to match current behavior:
   - Forward all query strings
   - No cookie forwarding
   - No header forwarding
3. Update `default_cache_behavior` to use `cache_policy_id` instead of
   `forwarded_values`
4. Remove deprecated `forwarded_values` block

**Expected Changes:**
```hcl
# main.tf - Add new resource
resource "aws_cloudfront_cache_policy" "redirect" {
  name        = "redirect-cache-policy-${random_id.suffix.hex}"
  min_ttl     = 0
  default_ttl = 86400
  max_ttl     = 31536000

  parameters_in_cache_key_and_forwarded_to_origin {
    query_strings_config {
      query_string_behavior = "all"
    }
    headers_config {
      header_behavior = "none"
    }
    cookies_config {
      cookie_behavior = "none"
    }
  }
}

# main.tf - Update default_cache_behavior
default_cache_behavior {
  allowed_methods        = ["GET", "HEAD"]
  cached_methods         = ["GET", "HEAD"]
  target_origin_id       = "redirect-origin"
  viewer_protocol_policy = "redirect-to-https"
  cache_policy_id        = aws_cloudfront_cache_policy.redirect.id
  # Remove forwarded_values block
}
```

**Testing:**
- Verify redirects still work after change
- Verify query strings are still forwarded
- Check CloudFront cache behavior in AWS console
- Test with various query string combinations

---

### 2.3 Reduce Code Duplication - Extract Hostname Logic [MEDIUM]

**Issue:** Hostname construction pattern repeated 5 times across files
**Impact:** Maintainability, risk of inconsistency
**Files to modify:** `locals.tf`, `main.tf`, `acm.tf`, `dns.tf`

**Implementation Steps:**
1. Add `redirect_domains` local to `locals.tf`
2. Replace all instances of the hostname construction pattern with
   `local.redirect_domains`
3. Verify all references are updated

**Expected Changes:**
```hcl
# locals.tf
locals {
  module_version = "0.3.0"

  redirect_domains = [
    for record in var.redirect_hostnames :
      trimprefix(
        join(".", [record, data.aws_route53_zone.redirect.name]),
        "."
      )
  ]

  default_module_tags = {
    created_by_module = "infrahouse/http-redirect/aws"
  }
}

# Then replace in main.tf:44, acm.tf:2,5, dns.tf:4,16
# From:
  trimprefix(join(".", [record, data.aws_route53_zone.redirect.name]), ".")
# To:
  local.redirect_domains[count.index]  # or appropriate reference
```

**Note:** Implementation requires careful handling of for expressions vs
count.index

---

### 2.4 Convert count to for_each for DNS Records [MEDIUM]

**Issue:** Using count means reordering hostnames destroys/recreates DNS
records
**Impact:** DNS propagation delays, potential downtime during updates
**Files to modify:** `dns.tf`

**Implementation Steps:**
1. Change `aws_route53_record.extra` from count to for_each
2. Change `aws_route53_record.extra_aaaa` from count to for_each
3. Change `aws_route53_record.caa_record` from count to for_each
4. Update resource addresses to use keys instead of indices
5. Document migration path in CHANGELOG

**Expected Changes:**
```hcl
# dns.tf
resource "aws_route53_record" "extra" {
  for_each = toset(var.redirect_hostnames)
  zone_id  = var.zone_id
  name     = trimprefix(
    join(".", [each.value, data.aws_route53_zone.redirect.name]),
    "."
  )
  type     = "A"

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.redirect.domain_name
    zone_id                = aws_cloudfront_distribution.redirect.hosted_zone_id
  }
}

# Similar for AAAA and CAA records
```

**Migration Note:**

This is a BREAKING CHANGE for existing deployments. Users will need to:
- Use `terraform state mv` to migrate existing resources
- Or accept destroy/recreate of DNS records (brief DNS propagation delay)

Document migration commands in CHANGELOG/README:
```bash
# For each hostname in redirect_hostnames
terraform state mv 'aws_route53_record.extra[0]' 'aws_route53_record.extra[""]'
terraform state mv 'aws_route53_record.extra[1]' 'aws_route53_record.extra["www"]'
```

---

### 2.5 Add CloudFront Price Class Variable [MEDIUM]

**Issue:** Always uses default (most expensive) price class
**Impact:** Unnecessarily high costs for many use cases
**Files to modify:** `variables.tf`, `main.tf`

**Implementation Steps:**
1. Add new variable `cloudfront_price_class` with validation
2. Default to `PriceClass_100` (most cost-effective)
3. Add to CloudFront distribution resource
4. Document cost implications in README

**Expected Changes:**
```hcl
# variables.tf
variable "cloudfront_price_class" {
  description = <<-EOT
    CloudFront distribution price class. PriceClass_100 (US, Canada, Europe),
    PriceClass_200 (+ Asia, Africa, Oceania, Middle East), PriceClass_All
    (all edge locations)
  EOT
  type        = string
  default     = "PriceClass_100"

  validation {
    condition = contains([
      "PriceClass_100",
      "PriceClass_200",
      "PriceClass_All"
    ], var.cloudfront_price_class)
    error_message = <<-EOT
      Price class must be PriceClass_100, PriceClass_200, or PriceClass_All.
    EOT
  }
}

# main.tf
resource "aws_cloudfront_distribution" "redirect" {
  # ... existing config
  price_class = var.cloudfront_price_class
}
```

**Testing:**
- Deploy with each price class value
- Verify CloudFront distribution uses specified price class
- Document cost differences in README

---

## Phase 3: Security Enhancements

Optional but recommended security improvements.

### 3.1 Add S3 Bucket Encryption [LOW]

**Issue:** No encryption configuration for S3 bucket
**Impact:** May violate compliance requirements
**Files to modify:** `s3.tf`

**Implementation Steps:**
1. Add `aws_s3_bucket_server_side_encryption_configuration` resource
2. Use AES256 (S3-managed keys)

**Expected Changes:**
```hcl
# s3.tf
resource "aws_s3_bucket_server_side_encryption_configuration" "redirect" {
  bucket = aws_s3_bucket.redirect.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

---

### 3.2 Make CAA Records Optional [MEDIUM]

**Issue:** CAA records may conflict with zone-level CAA records
**Impact:** Module fails if zone already has CAA records
**Files to modify:** `variables.tf`, `dns.tf`

**Implementation Steps:**
1. Add new variable `create_caa_records` (default true)
2. Add count condition to CAA record resource

**Expected Changes:**
```hcl
# variables.tf
variable "create_caa_records" {
  description = <<-EOT
    Create CAA records restricting certificate issuance to Amazon. Set to
    false if zone already has CAA records.
  EOT
  type        = bool
  default     = true
}

# dns.tf
resource "aws_route53_record" "caa_record" {
  count   = var.create_caa_records ? length(var.redirect_hostnames) : 0
  # ... rest of configuration
}
```

---

### 3.3 Add CloudFront Logging [HIGH]

**Issue:** No audit trail for traffic
**Impact:** Required for ISO 27001, SOC 2 compliance; can't investigate abuse or traffic patterns
**Files to modify:** `variables.tf`, `main.tf`

**Implementation Steps:**
1. Add variables for logging configuration
2. Add logging_config block to CloudFront distribution
3. Make logging **enabled by default** for compliance

**Expected Changes:**
```hcl
# variables.tf
variable "create_logging_bucket" {
  description = <<-EOT
    Create an S3 bucket for CloudFront logs using infrahouse/s3-bucket/aws
    module. Enables ISO 27001/SOC 2 compliant logging by default. Set to false
    to disable logging (not recommended for production).
  EOT
  type        = bool
  default     = true
}

variable "cloudfront_logging_prefix" {
  description = "Prefix for CloudFront log files in the logging bucket"
  type        = string
  default     = "cloudfront-logs/"
}

variable "cloudfront_logging_include_cookies" {
  description = "Include cookies in CloudFront logs"
  type        = bool
  default     = false
}

# s3-logs.tf (new file) - Create logging bucket using infrahouse module
module "cloudfront_logs_bucket" {
  count   = var.create_logging_bucket ? 1 : 0
  source  = "infrahouse/s3-bucket/aws"
  version = "1.7.1"

  # Use zone name for bucket, not redirect_domains (which may start with "")
  bucket = "${replace(data.aws_route53_zone.redirect.name, ".", "-")}-cloudfront-logs"

  # CloudFront requires specific bucket ownership settings for log delivery
  acl                      = null
  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  # Enable encryption for logs
  sse_algorithm = "AES256"

  # Lifecycle policy to expire old logs
  lifecycle_rules = [
    {
      id      = "expire-old-logs"
      enabled = true
      expiration = {
        days = 90
      }
      noncurrent_version_expiration = {
        noncurrent_days = 7
      }
    }
  ]

  # Grant CloudFront log delivery permissions
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudFrontLogsWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${replace(data.aws_route53_zone.redirect.name, ".", "-")}-cloudfront-logs/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.redirect.arn
          }
        }
      }
    ]
  })

  tags = merge(
    local.default_module_tags,
    {
      Purpose = "CloudFront access logs"
    }
  )
}

# locals.tf - Add logging bucket reference
locals {
  cloudfront_logging_bucket = (
    var.create_logging_bucket ?
      module.cloudfront_logs_bucket[0].bucket_domain_name :
      null
  )
}

# main.tf - Add logging config to CloudFront distribution
resource "aws_cloudfront_distribution" "redirect" {
  # ... existing config

  # Logging enabled by default for compliance (ISO 27001, SOC 2)
  dynamic "logging_config" {
    for_each = var.create_logging_bucket ? [1] : []
    content {
      bucket          = local.cloudfront_logging_bucket
      include_cookies = var.cloudfront_logging_include_cookies
      prefix          = var.cloudfront_logging_prefix
    }
  }
}

# outputs.tf - Add logging bucket output
output "cloudfront_logs_bucket_name" {
  description = "Name of the S3 bucket for CloudFront access logs"
  value       = var.create_logging_bucket ? module.cloudfront_logs_bucket[0].bucket_name : null
}

output "cloudfront_logs_bucket_arn" {
  description = "ARN of the S3 bucket for CloudFront access logs"
  value       = var.create_logging_bucket ? module.cloudfront_logs_bucket[0].bucket_arn : null
}
```

**Benefits of Using infrahouse/s3-bucket/aws Module:**
- ✅ **Compliance out-of-the-box**: Module follows security best practices
- ✅ **Encryption enabled**: Logs encrypted with AES256
- ✅ **Proper permissions**: CloudFront can write logs with correct IAM policy
- ✅ **Lifecycle management**: Old logs auto-expire after 90 days (configurable)
- ✅ **Consistent with other infrahouse modules**: Uses your own battle-tested S3 module
- ✅ **Zero user configuration**: Enabled by default, works immediately

**Important Notes:**
- Logging is **enabled by default** (`create_logging_bucket = true`)
- Logs automatically expire after 90 days to control storage costs
- Bucket uses first redirect domain name + "-cloudfront-logs" suffix
- Users can disable with `create_logging_bucket = false` (not recommended)
- Logs are encrypted at rest with S3-managed keys (AES256)

---

### 3.4 Add Optional WAF Integration [LOW]

**Issue:** No DDoS protection or request filtering
**Impact:** Vulnerable to abuse
**Files to modify:** `variables.tf`, `main.tf`

**Implementation Steps:**
1. Add optional `web_acl_id` variable
2. Add to CloudFront distribution resource

**Expected Changes:**
```hcl
# variables.tf
variable "web_acl_id" {
  description = "Optional WAF Web ACL ID for CloudFront distribution"
  type        = string
  default     = null
}

# main.tf
resource "aws_cloudfront_distribution" "redirect" {
  # ... existing config
  web_acl_id = var.web_acl_id
}
```

---

## Phase 4: Nice-to-Have Enhancements

Optional features that improve user experience.

### 4.1 Add Security Headers Policy [MEDIUM]

**Issue:** No security headers in responses
**Impact:** Lower security score, missing best practices
**Files to modify:** `main.tf` (new resource)

**Implementation Steps:**
1. Create `aws_cloudfront_response_headers_policy` resource
2. Add HSTS, X-Content-Type-Options, X-Frame-Options, etc.
3. Attach to default_cache_behavior

**Expected Changes:**
```hcl
# main.tf
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "redirect-security-headers-${random_id.suffix.hex}"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
}

# Update default_cache_behavior
default_cache_behavior {
  # ... existing config
  response_headers_policy_id = (
    aws_cloudfront_response_headers_policy.security_headers.id
  )
}
```

---

### 4.3 Add Complete Tagging [LOW]

**Issue:** Inconsistent tagging across resources
**Impact:** Harder to track costs and ownership
**Files to modify:** `s3.tf`

**Implementation Steps:**
1. Add module version tag to S3 bucket
2. Add default tags from locals

---

### 4.4 Increase ACM Validation TTL [LOW]

**Issue:** TTL of 60 seconds for validation records
**Impact:** Higher DNS query load than necessary
**Files to modify:** `acm.tf`

**Implementation Steps:**
1. Change TTL from 60 to 300 seconds

---

## Phase 5: Testing Improvements

Enhance test coverage to catch issues earlier.

### 5.1 Add Multi-Region Test [HIGH]

**Purpose:** Verify module works with dual-provider setup (main region + us-east-1)
**Files to modify:** `tests/test_module.py`, `test_data/main/providers.tf`

**Implementation Steps:**
1. Configure test to use us-west-2 as main region and us-east-1 for ACM
2. Update test fixture to pass both providers to module
3. Verify ACM certificate is created in us-east-1
4. Verify all other resources (CloudFront, S3, Route53) are in us-west-2
5. Verify redirects work correctly

**Expected Test Configuration:**
```python
# tests/test_module.py
@pytest.fixture()
def test_zone():
    """Route53 zone for testing."""
    return os.environ.get("TEST_ZONE")

@pytest.fixture()
def main_region():
    """Main deployment region."""
    return "us-west-2"

@pytest.fixture()
def acm_region():
    """ACM certificate region (must be us-east-1 for CloudFront)."""
    return "us-east-1"

def test_multi_region_redirect(
    service_network,
    test_zone,
    main_region,
    acm_region
):
    """Test module with dual-provider setup."""

    # Generate terraform.tfvars with both regions
    terraform_vars = {
        "test_zone": test_zone,
        "main_region": main_region,
        "acm_region": acm_region,
    }

    with terraform_apply(
        "test_data/main",
        json_var=json.dumps(terraform_vars)
    ) as tf_output:
        # Verify ACM certificate is in us-east-1
        assert tf_output["acm_certificate_arn"]["value"].startswith(
            f"arn:aws:acm:{acm_region}:"
        )

        # Verify CloudFront distribution exists
        distribution_id = tf_output["cloudfront_distribution_id"]["value"]
        assert distribution_id.startswith("E")

        # Test redirect functionality
        redirect_domain = tf_output["redirect_domains"]["value"][0]
        response = requests.get(
            f"https://{redirect_domain}/test",
            allow_redirects=False
        )
        assert response.status_code == 301
        assert "Location" in response.headers
```

**Expected Test Fixture Configuration:**
```hcl
# test_data/main/providers.tf
provider "aws" {
  region = var.main_region
}

provider "aws" {
  alias  = "us-east-1"
  region = var.acm_region
}

# test_data/main/main.tf
module "redirect" {
  source = "../../"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  redirect_to        = var.redirect_to
  redirect_hostnames = var.redirect_hostnames
  zone_id            = data.aws_route53_zone.test.zone_id
}

# test_data/main/variables.tf
variable "main_region" {
  description = "Main deployment region"
  type        = string
  default     = "us-west-2"
}

variable "acm_region" {
  description = "ACM certificate region"
  type        = string
  default     = "us-east-1"
}
```

**Validation Checks:**
- [ ] ACM certificate ARN contains `us-east-1` region
- [ ] CloudFront distribution created successfully
- [ ] S3 bucket exists
- [ ] Route53 records created
- [ ] HTTP redirect returns 301 status
- [ ] Location header contains correct redirect URL
- [ ] Query strings preserved
- [ ] Paths preserved

---

### 5.2 Add Query String Preservation Test [MEDIUM]

**Purpose:** Verify redirects preserve query strings
**Files to modify:** `tests/test_module.py`

**Implementation Steps:**
1. Add test that includes query strings in request
2. Verify redirect Location header contains all query parameters

---

### 5.3 Add Path Preservation Test [MEDIUM]

**Purpose:** Verify redirects preserve URL paths
**Files to modify:** `tests/test_module.py`

**Implementation Steps:**
1. Add test with deep URL paths
2. Verify redirect Location header includes full path

---

### 5.4 Add Idempotency Test [HIGH]

**Purpose:** Verify second apply shows no changes
**Files to modify:** `tests/test_module.py`

**Implementation Steps:**
1. Apply module
2. Run terraform plan
3. Assert no changes detected

---

## Phase 6: Documentation Updates

### 6.1 Update README with Provider Configuration [CRITICAL]

**Part of Phase 1**
- Add clear explanation of us-east-1 requirement
- Show complete usage example with provider blocks
- Explain WHY CloudFront requires us-east-1 certificates

### 6.2 Add Cost Documentation [MEDIUM]

- Document price class options and cost implications
- Provide example cost calculations
- Link to AWS pricing pages

### 6.3 Add Troubleshooting Guide [LOW]

- Common errors and solutions
- How to verify deployment
- How to debug DNS issues

### 6.4 Add Architecture Diagram [LOW]

- Visual representation of created resources
- Data flow diagram
- DNS resolution path

---

## Implementation Order for v1.0.0 Release

All phases will be implemented in a single v1.0.0 release. Since we're already
introducing breaking changes (provider alias requirement), it makes sense to
bundle all improvements together.

### Priority 1: Critical Fixes (Must Have)

1. Fix us-east-1 provider alias (BLOCKER)
2. Add AAAA records for IPv6
3. Add outputs.tf
4. Add input validation
5. Fix variable descriptions

### Priority 2: Important Improvements (Must Have)

1. **Add URL path redirect support** (USER REQUESTED - HIGH PRIORITY)
2. Replace deprecated CloudFront config (cache policies)
3. Extract hostname logic to locals (reduce duplication)
4. Add CloudFront price class variable (cost optimization)
5. Convert count to for_each for DNS records (better state management)

### Priority 3: Security & Compliance (Must Have)

1. Add S3 bucket encryption
2. Add CloudFront logging with infrahouse/s3-bucket module (ISO 27001/SOC 2)
3. Make CAA records optional (avoid conflicts)
4. Add optional WAF integration

### Priority 4: Polish (Nice to Have)

1. Add security headers policy
2. Improve tagging consistency
3. Increase ACM validation TTL

### Priority 5: Documentation & Testing (Must Have)

1. Update README with provider configuration
2. Add cost documentation
3. Comprehensive test coverage (all validation steps)
4. Migration guide for breaking changes

---

## Testing Strategy

**Test Location:** All validation in single test file `tests/test_module.py`

**Test Workflow:**
1. Local development: Run `make test-keep` (keeps resources) or `make test-clean`
   (destroys resources)
2. Create PR with changes
3. CI automatically runs tests to confirm functionality
4. After tests pass: Merge PR
5. Release new module version

**Test Structure:**

The `test_module()` function performs all validation steps in sequence within a
single Terraform apply context:

```python
def test_module(service_network, test_zone, main_region, acm_region):
    """
    Comprehensive test for HTTP redirect module.

    Validates all functionality in a single test run:
    - Multi-region setup (main region + us-east-1 for ACM)
    - Resource creation and configuration
    - DNS records (A and AAAA)
    - Module outputs
    - HTTP redirect functionality
    - Query string and path preservation
    - Security configurations
    """

    with terraform_apply("test_data/main", ...) as tf_output:
        # Phase 1 Validations
        validate_multi_region_setup(tf_output, acm_region)
        validate_ipv6_support(tf_output)
        validate_module_outputs(tf_output)

        # Phase 2 Validations
        validate_hostname_redirect(tf_output)
        validate_path_redirects(tf_output)
        validate_query_string_preservation(tf_output)

        # Phase 3 Validations
        validate_security_configuration(tf_output)
        validate_logging_configuration(tf_output)

        # Phase 4 Validations (optional)
        validate_security_headers(tf_output)
```

### Validation Steps by Phase

**Phase 1 Validations (Critical Fixes):**
- [ ] **Multi-region setup:** ACM certificate ARN contains `us-east-1` region
- [ ] **Multi-region setup:** CloudFront, S3, Route53 created successfully
- [ ] **IPv6 support:** AAAA records exist for all redirect hostnames
- [ ] **IPv6 support:** AAAA records point to CloudFront distribution
- [ ] **Module outputs:** All output values present and correct
- [ ] **Module outputs:** `acm_certificate_arn` output is valid
- [ ] **Module outputs:** `redirect_domains` list is correct
- [ ] **Module outputs:** DNS records map contains A and AAAA entries
- [ ] **Basic redirect:** HTTP request returns 301 status
- [ ] **Basic redirect:** Location header points to correct destination

**Phase 2 Validations (Important Improvements):**
- [ ] **Hostname redirect:** `foo.com/path` → `bar.com/path` (preserves path)
- [ ] **Path redirect:** `foo.com/x` → `bar.com/base/x` (with preserve_path=true)
- [ ] **Fixed path redirect:** `foo.com/x` → `bar.com/base` (with
      preserve_path=false)
- [ ] **Query strings:** `foo.com/path?a=1&b=2` preserves all query parameters
- [ ] **Query strings:** Location header contains `?a=1&b=2`
- [ ] **Deep paths:** `foo.com/deep/nested/path` → `bar.com/deep/nested/path`
- [ ] **Cache policy:** CloudFront uses cache_policy_id (not forwarded_values)
- [ ] **Price class:** CloudFront distribution uses configured price class

**Phase 3 Validations (Security Enhancements):**
- [ ] **S3 encryption:** Bucket has server-side encryption enabled (AES256)
- [ ] **CloudFront logging:** Logging bucket exists when enabled
- [ ] **CloudFront logging:** CloudFront writes logs to correct bucket
- [ ] **CloudFront logging:** Logs have correct prefix
- [ ] **WAF integration:** WAF ACL ID attached when provided

**Phase 4 Validations (Nice-to-Have):**
- [ ] **Security headers:** Response includes Strict-Transport-Security header
- [ ] **Security headers:** Response includes X-Content-Type-Options header
- [ ] **Security headers:** Response includes X-Frame-Options header
- [ ] **Security headers:** Response includes Referrer-Policy header
- [ ] **Tagging:** All resources have module version tag
- [ ] **Tagging:** All resources have created_by_module tag

**Example Validation Functions:**

```python
def validate_multi_region_setup(tf_output, acm_region):
    """Validate ACM cert in us-east-1, other resources in main region."""
    acm_arn = tf_output["acm_certificate_arn"]["value"]
    assert f":acm:{acm_region}:" in acm_arn, \
        f"ACM cert should be in {acm_region}, got: {acm_arn}"

    cf_id = tf_output["cloudfront_distribution_id"]["value"]
    assert cf_id.startswith("E"), \
        f"Invalid CloudFront distribution ID: {cf_id}"

def validate_query_string_preservation(tf_output):
    """Validate query strings are preserved during redirect."""
    domain = tf_output["redirect_domains"]["value"][0]

    response = requests.get(
        f"https://{domain}/test?foo=bar&baz=qux",
        allow_redirects=False
    )

    assert response.status_code == 301
    location = response.headers.get("Location")
    assert "foo=bar" in location, "Query parameter 'foo' not preserved"
    assert "baz=qux" in location, "Query parameter 'baz' not preserved"

def validate_path_redirects(tf_output):
    """Validate path-based redirects work correctly."""
    domain = tf_output["redirect_domains"]["value"][0]

    # Test 1: Path preservation
    response = requests.get(
        f"https://{domain}/deep/nested/path",
        allow_redirects=False
    )
    assert response.status_code == 301
    location = response.headers.get("Location")
    assert "/deep/nested/path" in location, "Path not preserved"

    # Test 2: Can add more path tests as needed
```

**Test Execution:**

```bash
# During development - keep resources for inspection
make test-keep

# Clean run - destroys resources after test
make test-clean

# Test runs automatically in CI after PR creation
# Once tests pass: merge PR and release
```

---

## Risk Assessment

### High Risk Changes

1. **Provider alias addition** - Breaking change, requires user updates
   - Mitigation: Clear documentation, migration guide

2. **count to for_each conversion** - Breaking change, resource recreation
   - Mitigation: Provide state migration commands, make optional

### Medium Risk Changes

1. **CloudFront cache policy** - Behavior change, potential cache issues
   - Mitigation: Thorough testing, verify cache behavior unchanged

2. **Making CAA optional** - May affect security posture
   - Mitigation: Default to true (current behavior)

### Low Risk Changes

1. All additive features (new variables, outputs) - No breaking changes
2. Security enhancements - Only add protections

---

## Success Criteria for v1.0.0

### Functionality

- [ ] Module works from any AWS region (dual-provider setup)
- [ ] IPv6 fully supported (AAAA records)
- [ ] URL path redirects work correctly (hostname and path)
- [ ] Query strings and paths preserved correctly
- [ ] No Terraform deprecation warnings

### Code Quality

- [ ] All outputs documented and tested
- [ ] Input validation prevents common errors
- [ ] Code duplication eliminated (hostname logic in locals)
- [ ] Consistent use of for_each instead of count

### Security & Compliance

- [ ] S3 bucket encryption enabled
- [ ] CloudFront logging enabled by default (ISO 27001/SOC 2)
- [ ] Security headers policy implemented
- [ ] All resources properly tagged

### Cost Optimization

- [ ] Users can control CloudFront costs via price class
- [ ] Default to PriceClass_100 (cost-effective)

### Documentation

- [ ] README has clear provider configuration example
- [ ] Migration guide for breaking changes
- [ ] Cost documentation with examples
- [ ] All variables and outputs documented

### Testing

- [ ] >90% test coverage
- [ ] Multi-region test passes
- [ ] All validation steps in test_module() pass
- [ ] Idempotency test passes

### Release Readiness

- [ ] Zero known critical bugs
- [ ] Production validation in test account
- [ ] CHANGELOG.md updated with all changes
- [ ] Breaking changes clearly documented

---

## Breaking Changes Summary for v1.0.0

### Breaking Change 1: Provider Alias Requirement

**Impact:** ALL users must update their module invocations

**Required Changes:**
- Users MUST add us-east-1 provider alias to their configuration
- Users MUST pass both providers to the module

**Before (v0.3.0):**
```hcl
module "redirect" {
  source  = "infrahouse/http-redirect/aws"
  version = "0.3.0"

  redirect_to = "example.com"
  zone_id     = aws_route53_zone.example.zone_id
}
```

**After (v1.0.0):**
```hcl
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

module "redirect" {
  source  = "infrahouse/http-redirect/aws"
  version = "1.0.0"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  redirect_to = "example.com"
  zone_id     = aws_route53_zone.example.zone_id
}
```

### Breaking Change 2: DNS Records Use for_each

**Impact:** Users with existing deployments will see DNS record recreation in
plan

**Required Migration:**
Users must run `terraform state mv` commands to migrate DNS records:

```bash
# For each hostname in redirect_hostnames (example with ["", "www"])
terraform state mv \
  'module.redirect.aws_route53_record.extra[0]' \
  'module.redirect.aws_route53_record.extra[""]'

terraform state mv \
  'module.redirect.aws_route53_record.extra[1]' \
  'module.redirect.aws_route53_record.extra["www"]'

# Same for AAAA records
terraform state mv \
  'module.redirect.aws_route53_record.extra_aaaa[0]' \
  'module.redirect.aws_route53_record.extra_aaaa[""]'

terraform state mv \
  'module.redirect.aws_route53_record.extra_aaaa[1]' \
  'module.redirect.aws_route53_record.extra_aaaa["www"]'
```

**Alternative:** Accept DNS record recreation (brief DNS propagation delay)

### Breaking Change 3: New Default Price Class

**Impact:** CloudFront distributions will use PriceClass_100 by default instead
of PriceClass_All

**Migration:** Users who want to keep current behavior (all edge locations)
must explicitly set:

```hcl
cloudfront_price_class = "PriceClass_All"
```

### Breaking Change 4: Logging Enabled by Default

**Impact:** New S3 bucket created for CloudFront logs by default

**Migration:** Users who don't want logging must explicitly disable:

```hcl
create_logging_bucket = false
```

**Cost Impact:** Minimal - logs expire after 90 days automatically

---

## Rollback Plan

Each phase should maintain backward compatibility where possible:
1. Test against previous version's outputs
2. Maintain state compatibility
3. Document any required state migrations
4. Provide rollback instructions in CHANGELOG

If critical issues found:
1. Revert Git commits
2. Republish previous version
3. Update documentation with known issues
4. Fix in next patch release

---

## Notes for Implementation

1. **Commit Strategy:**
   - One commit per logical change
   - Use Conventional Commits format (feat:, fix:, docs:, etc.)
   - Reference issue numbers if available

2. **PR Strategy:**
   - One PR per phase
   - Include tests with each PR
   - Update CHANGELOG.md
   - Bump version according to semver

3. **Version Bumping:**
   - Update both README.md and locals.tf
   - Use .bumpversion.cfg
   - Tag releases in Git

4. **Documentation:**
   - README.md is auto-generated by terraform-docs
   - Update .terraform-docs.yml as needed
   - Run pre-commit hook before committing

5. **Testing:**
   - Run `make test` after each change
   - Consider `make test-keep` for debugging
   - Verify in real AWS account

---

## Questions for Review

Before starting implementation:

1. **Priority Confirmation:**
   - Agree on phase order?
   - Any items to add/remove?

2. **Breaking Changes:**
   - Accept provider alias requirement for v0.4.0?
   - Defer for_each conversion to later version?

3. **Security:**
   - Which security features are mandatory?
   - Default logging to enabled or disabled?

4. **Testing:**
   - Which regions to test?
   - Need IPv6 testing environment?

5. **Timeline:**
   - Target dates for each phase?
   - Resource availability?

6. **URL Path Redirects (Phase 2.1):**
   - Prefer Option 1 (path preservation) or Option 2 (path replacement)?
   - Should `preserve_path` default to true or false?

---

## End of Implementation Plan

This plan provides a clear path from the current state (with critical issues)
to a production-ready v1.0.0 module. Each phase builds on the previous one and
can be delivered incrementally.

**Next Step:** Review this plan, get approval, then start with Phase 1
(Critical Fixes).
