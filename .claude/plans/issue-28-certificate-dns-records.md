# Implementation Plan: Issue #28 - Add option to disable certificate DNS records

**Issue:** https://github.com/infrahouse/terraform-aws-http-redirect/issues/28

**Status:** ✅ COMPLETED (2026-01-30)

**Goal:** Add option to disable certificate DNS records (CAA and validation) to avoid conflicts with other
modules managing the same domain.

## Problem Summary

When using `terraform-aws-http-redirect` alongside modules like `terraform-aws-ecs` that already manage DNS
records for the same domain, there are conflicts:

1. **CAA record conflict** - both modules try to create the same CAA record
2. **Certificate validation CNAME conflict** - ACM generates deterministic validation tokens per domain/account,
   so both certificates share the same validation record

### Key Finding: ACM Deterministic Validation Records

**ACM generates deterministic validation records per domain per AWS account, regardless of region.**

Both the CNAME name AND value are identical across regions:

```bash
# us-west-1 certificate
$ aws acm describe-certificate --region us-west-1 --certificate-arn <arn> \
    --query "Certificate.DomainValidationOptions[0].ResourceRecord"
{
    "Name": "_61ab1088101cb318274e5e87ca528301.caa-testbed.development.tinyfish.io.",
    "Type": "CNAME",
    "Value": "_c8289f231024b40ad30d30bee1062deb.jkddzztszm.acm-validations.aws."
}

# us-east-1 certificate (SAME domain, different region)
$ aws acm describe-certificate --region us-east-1 --certificate-arn <arn> \
    --query "Certificate.DomainValidationOptions[0].ResourceRecord"
{
    "Name": "_61ab1088101cb318274e5e87ca528301.caa-testbed.development.tinyfish.io.",
    "Type": "CNAME",
    "Value": "_c8289f231024b40ad30d30bee1062deb.jkddzztszm.acm-validations.aws."
}
```

This means when one module creates the validation CNAME, another module trying to create it for the same
domain will fail with "already exists" - even if the certificates are in different regions.

### Example Error Messages

```
Error: creating Route53 Record: InvalidChangeBatch: [Tried to create resource record set
[name='example.dev.example.com.', type='CAA'] but it already exists]
```

```
Error: creating Route53 Record: InvalidChangeBatch: [Tried to create resource record set
[name='_61ab1088101cb318274e5e87ca528301.example.dev.example.com.', type='CNAME'] but it already exists]
```

## Implementation Steps

### Phase 1: Add New Variable

**File:** `variables.tf`

Add `create_certificate_dns_records` variable:

```hcl
variable "create_certificate_dns_records" {
  description = <<-EOT
    Whether to create DNS records required for certificate issuance.
    When set to true (default), the module creates:
    - CAA records (Certificate Authority Authorization)
    - ACM certificate validation CNAME records

    Set to false if these records are already managed by another module
    (e.g., terraform-aws-ecs via terraform-aws-website-pod for the same domain).
    The A/AAAA records pointing to CloudFront are always created regardless
    of this setting.
  EOT
  type        = bool
  default     = true
}
```

### Phase 2: Modify CAA Record in dns.tf

**File:** `dns.tf`

Update `aws_route53_record.caa_record` to conditionally create based on the new variable:

```hcl
resource "aws_route53_record" "caa_record" {
  for_each = var.create_certificate_dns_records ? local.redirect_domains_map : {}
  zone_id  = var.zone_id
  name     = each.value
  type     = "CAA"
  ttl      = 300
  records = [
    "0 issue \"amazon.com\"",
    "0 issuewild \";\""
  ]
}
```

### Phase 3: Modify Certificate Validation Record in acm.tf

**File:** `acm.tf`

Update `aws_route53_record.cert_validation` to conditionally create:

```hcl
resource "aws_route53_record" "cert_validation" {
  provider = aws.us-east-1
  for_each = var.create_certificate_dns_records ? {
    for dvo in aws_acm_certificate.redirect.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}
  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [
    each.value.record
  ]
  ttl = 300
}
```

### Phase 4: Update Certificate Validation Resource

**File:** `acm.tf`

Update `aws_acm_certificate_validation.redirect` to handle both scenarios:

```hcl
resource "aws_acm_certificate_validation" "redirect" {
  provider        = aws.us-east-1
  certificate_arn = aws_acm_certificate.redirect.arn

  # Only specify FQDNs when we create the records ourselves.
  # When create_certificate_dns_records = false, the validation resource
  # will still wait for the certificate to become valid, but relies on
  # existing DNS records created by another module.
  validation_record_fqdns = var.create_certificate_dns_records ? [
    for d in aws_route53_record.cert_validation : d.fqdn
  ] : null
}
```

**Rationale:**

The `aws_acm_certificate_validation` resource serves as a "waiter" that blocks Terraform until the ACM
certificate is validated. The `validation_record_fqdns` argument is optional:

- **When `true` (default):** Waits and validates using our DNS records (current behavior)
- **When `false`:** Still waits for certificate validation, but relies on existing DNS records from another
  module. Since ACM generates deterministic validation tokens per domain/account, the existing CNAME records
  will validate our new certificate too.

This approach ensures CloudFront never tries to use an unvalidated certificate.

### Phase 5: Verify CloudFront Dependency

**File:** `main.tf`

The CloudFront distribution uses `aws_acm_certificate.redirect.arn` directly. The
`aws_acm_certificate_validation` resource ensures the certificate is valid before CloudFront uses it.

No changes needed to `main.tf` - the implicit dependency chain is:
1. `aws_acm_certificate.redirect` creates the certificate
2. `aws_acm_certificate_validation.redirect` waits for validation (using existing or new DNS records)
3. CloudFront distribution uses the validated certificate

### Phase 6: Documentation Updates

**File:** `docs/configuration.md`

Add documentation for the new variable with usage examples.

**File:** `docs/changelog.md`

Add changelog entry for the new feature.

## Files to Modify Summary

| File | Changes |
|------|---------|
| `variables.tf` | Add `create_certificate_dns_records` variable |
| `dns.tf` | Add conditional `for_each` on `caa_record` |
| `acm.tf` | Add conditional `for_each` on `cert_validation`, update validation resource |
| `docs/configuration.md` | Document new variable |
| `docs/changelog.md` | Add changelog entry |

## Usage Example

```hcl
module "http-redirect" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "~> 1.2"

  redirect_hostnames = [""]
  redirect_to        = "new-domain.com"
  zone_id            = data.aws_route53_zone.example.zone_id

  # Skip CAA and validation records - managed by ECS/website-pod module
  create_certificate_dns_records = false

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
}
```

## Testing

### Test Strategy

We need to verify that the module works correctly when certificate DNS records are managed externally.
The test will:

1. **First** a pytest fixture (`shared_certificate`) creates the "external" ACM certificate with its DNS
   records (simulating what terraform-aws-ecs or terraform-aws-website-pod would do)
2. **Then** the test runs `terraform_apply` against `test_data/main` with `create_certificate_dns_records = false`
3. **Verify** the redirect works and no duplicate DNS records are created

### Test Fixture Structure

```
test_data/
├── main/                          # Used by both test_module and test_shared_certificate_dns_records
│   ├── main.tf                    # Module invocation (updated to support create_certificate_dns_records)
│   ├── variables.tf               # Add create_certificate_dns_records variable
│   └── ...
└── shared_certificate/            # Pytest fixture to create "external" certificate
    ├── main.tf                    # Creates ACM cert + CAA + validation records
    ├── providers.tf
    ├── variables.tf
    └── outputs.tf
```

### Update test_data/main to support create_certificate_dns_records

**File:** `test_data/main/variables.tf` - Add new variable:

```hcl
variable "create_certificate_dns_records" {
  description = "Whether to create certificate DNS records"
  type        = bool
  default     = true
}
```

**File:** `test_data/main/main.tf` - Pass new variable to module:

```hcl
module "redirect" {
  source = "../../"

  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  redirect_hostnames = [""]
  redirect_to        = var.redirect_to
  zone_id            = var.test_zone_id

  # Support for shared certificate testing
  create_certificate_dns_records = var.create_certificate_dns_records

  # Other settings
  create_logging_bucket                    = true
  cloudfront_logging_bucket_force_destroy  = true
}
```

### Pytest Fixture: test_data/shared_certificate/main.tf

This fixture creates the "external" certificate and DNS records that simulate another module:

```hcl
data "aws_route53_zone" "test" {
  zone_id = var.zone_id
}

locals {
  # Apex domain (empty hostname prefix)
  test_domain = data.aws_route53_zone.test.name
}

# ==============================================================================
# Simulate "external" module creating certificate and DNS records
# (This is what terraform-aws-ecs/website-pod would do)
#
# Note: ECS/website-pod creates ALB certificates in the user's region (not us-east-1).
# Only CloudFront requires certificates in us-east-1.
# ACM generates deterministic validation tokens per domain/account, so the same
# validation CNAME works for certificates in any region.
# ==============================================================================

resource "aws_acm_certificate" "external" {
  # No provider alias - uses default provider (user's region, like ECS/website-pod does)
  domain_name       = local.test_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name    = "external-cert-${local.test_domain}"
    Purpose = "Simulate external module certificate (like terraform-aws-ecs)"
  }
}

resource "aws_route53_record" "external_validation" {
  for_each = {
    for dvo in aws_acm_certificate.external.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 300
}

resource "aws_route53_record" "external_caa" {
  zone_id = var.zone_id
  name    = local.test_domain
  type    = "CAA"
  ttl     = 300
  records = [
    "0 issue \"amazon.com\"",
    "0 issuewild \";\""
  ]
}

resource "aws_acm_certificate_validation" "external" {
  # No provider alias - same region as the certificate
  certificate_arn         = aws_acm_certificate.external.arn
  validation_record_fqdns = [for r in aws_route53_record.external_validation : r.fqdn]
}
```

### Pytest Fixture: test_data/shared_certificate/outputs.tf

```hcl
output "external_certificate_arn" {
  description = "ACM certificate ARN from external (simulated) module"
  value       = aws_acm_certificate.external.arn
}

output "test_domain" {
  description = "The test domain"
  value       = local.test_domain
}
```

### Pytest Fixture: test_data/shared_certificate/variables.tf

```hcl
variable "zone_id" {
  description = "Route53 zone ID for testing"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "role_arn" {
  description = "IAM role ARN for testing"
  type        = string
  default     = null
}
```

### Pytest Fixture: test_data/shared_certificate/providers.tf

```hcl
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
      created_by = "infrahouse/terraform-aws-http-redirect"
    }
  }
}
```

### Python Fixture: tests/conftest.py

Add the `shared_certificate` fixture:

```python
@pytest.fixture(scope="session")
def shared_certificate(subzone, test_role_arn, aws_region, keep_after):
    """
    Create external ACM certificate and DNS records to simulate another module.

    This fixture creates:
    - ACM certificate for the test domain
    - CAA record
    - Certificate validation CNAME record

    The http-redirect module test will then use create_certificate_dns_records=false
    to avoid conflicts with these existing records.
    """
    zone_id = subzone["subzone_id"]["value"]

    terraform_module_dir = osp.join(TERRAFORM_ROOT_DIR, "shared_certificate")
    cleanup_dot_terraform(terraform_module_dir)

    with open(osp.join(terraform_module_dir, "terraform.tfvars"), "w") as fp:
        fp.write(
            dedent(
                f"""
                region  = "{aws_region}"
                zone_id = "{zone_id}"
                """
            )
        )
        if test_role_arn:
            fp.write(
                dedent(
                    f"""
                role_arn = "{test_role_arn}"
                """
                )
            )

    with terraform_apply(
        terraform_module_dir,
        destroy_after=not keep_after,
        json_output=True,
    ) as tf_output:
        LOG.info("shared_certificate fixture created: %s", json.dumps(tf_output, indent=4))
        yield tf_output
```

### Python Test: tests/test_module.py

Add new test function that uses the `shared_certificate` fixture:

```python
@pytest.mark.parametrize(
    "aws_provider_version", ["~> 5.56", "~> 6.0"], ids=["aws-5", "aws-6"]
)
def test_shared_certificate_dns_records(
    subzone,
    test_role_arn,
    keep_after,
    aws_region,
    boto3_session,
    aws_provider_version,
    shared_certificate,
):
    """
    Test http-redirect module when certificate DNS records are managed externally.

    This test simulates the scenario from issue #28 where another module
    (e.g., terraform-aws-ecs via terraform-aws-website-pod) has already created
    CAA and ACM validation records for the same domain.

    The shared_certificate fixture creates the external certificate and DNS records.
    This test then runs the http-redirect module with create_certificate_dns_records=false.

    The test verifies that:
    1. The module successfully creates a new ACM certificate
    2. The certificate is validated using existing DNS records
    3. CloudFront distribution works correctly
    4. HTTP redirects work as expected
    5. No duplicate DNS records are created (would cause Terraform error)
    """
    # Get zone ID from subzone fixture
    zone_id = subzone["subzone_id"]["value"]

    # Use test_data/main with create_certificate_dns_records = false
    terraform_module_dir = osp.join(TERRAFORM_ROOT_DIR, "main")
    cleanup_dot_terraform(terraform_module_dir)
    update_terraform_tf(terraform_module_dir, aws_provider_version)

    with open(osp.join(terraform_module_dir, "terraform.tfvars"), "w") as fp:
        fp.write(
            dedent(
                f"""
                region                         = "{aws_region}"
                test_zone_id                   = "{zone_id}"
                redirect_to                    = "infrahouse.com"
                create_certificate_dns_records = false
                """
            )
        )
        if test_role_arn:
            fp.write(
                dedent(
                    f"""
                role_arn = "{test_role_arn}"
                """
                )
            )

    with terraform_apply(
        terraform_module_dir,
        destroy_after=not keep_after,
        json_output=True,
    ) as tf_output:
        LOG.info("%s", json.dumps(tf_output, indent=4))

        zone_name = tf_output["zone_name"]["value"]

        # Verify the module's certificate is different from the external one
        module_cert_arn = tf_output["acm_certificate_arn"]["value"]
        external_cert_arn = shared_certificate["external_certificate_arn"]["value"]

        assert module_cert_arn is not None, "Module certificate should exist"
        assert external_cert_arn != module_cert_arn, "Certificates should be different"

        # Verify CloudFront distribution was created
        cf_distribution_id = tf_output["cloudfront_distribution_id"]["value"]
        assert cf_distribution_id.startswith("E"), (
            f"Invalid CloudFront distribution ID: {cf_distribution_id}"
        )

        # Add timestamp for cache-busting
        import time
        cache_bust = f"cachebust={int(time.time() * 1000)}"

        # Verify redirect works
        response = get(
            f"https://{zone_name}/test-path?query=value&{cache_bust}",
            allow_redirects=False,
        )

        assert response.status_code == 301, (
            f"Expected 301 redirect, got {response.status_code}"
        )

        location = response.headers.get("Location")
        assert location is not None, "Location header should be present"
        assert "infrahouse.com" in location, (
            f"Redirect should point to infrahouse.com, got: {location}"
        )
        assert "/test-path" in location, (
            f"Path should be preserved in redirect, got: {location}"
        )
        assert "query=value" in location, (
            f"Query string should be preserved, got: {location}"
        )

        LOG.info(
            "Test passed: http-redirect works with externally managed "
            "certificate DNS records"
        )
```

### Test Validation Checklist

The test verifies:

- [ ] **Certificate creation:** Module creates its own ACM certificate (different from external)
- [ ] **Certificate validation:** Module certificate is validated using existing DNS records
- [ ] **No DNS conflicts:** Terraform apply succeeds without "already exists" errors
- [ ] **CloudFront deployment:** Distribution is created and deployed successfully
- [ ] **Redirect functionality:** HTTP 301 redirect works correctly
- [ ] **Path preservation:** Request path is preserved in redirect
- [ ] **Query string preservation:** Query parameters are preserved in redirect

## Backward Compatibility

- Default value is `true`, preserving existing behavior
- No breaking changes to existing deployments
- Existing tests continue to pass unchanged