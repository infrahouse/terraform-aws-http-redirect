# Upgrading Guide

## 1.3.x to 2.0.0

### Upgrading from 1.3.2

If you are already on 1.3.2, your resources already use the random suffix
naming. Upgrading to 2.0.0 should be seamless -- run `terraform plan` to
confirm no resources are destroyed/recreated. The only new change in 2.0.0
is the `depends_on` fix for the CloudFront logs bucket race condition,
which has no effect on existing deployments.

### Upgrading from 1.3.1 or earlier

Version 2.0.0 fixes name collisions when running multiple module instances
in the same AWS account. The fix uses a random suffix in resource names,
which means **upgrading in-place will destroy and recreate** three
resources:

| Resource | Old name (<=1.3.1) | New name (2.0.0) |
|---|---|---|
| CloudFront cache policy | `redirect-cache-policy-<zone_id>` | `redirect-cache-policy-<random>` |
| CloudFront response headers policy | `redirect-security-headers-<zone_id>` | `redirect-security-headers-<random>` |
| CloudFront logs S3 bucket | `<zone>-cloudfront-logs` | `<zone>-cf-logs-<random>` |

The logs bucket destruction means **data loss** unless you follow one of
the migration approaches below.

Additionally, 2.0.0 adds a new required provider: `hashicorp/random`.
Run `terraform init -upgrade` after updating the module version.

### Approach A: State Surgery

Best for non-critical environments, or when a brief logging gap is
acceptable. No traffic disruption.

```bash
# Assume your module block is called "redirect".
# Substitute your actual module name throughout.

# 1. Update module version to 2.0.0, run init
terraform init -upgrade

# 2. Create the random string first (determines new bucket name)
terraform apply -target=module.redirect.random_string.this

# 3. Plan to see old/new bucket names
terraform plan
# Note the old bucket name, e.g. "example-com-cloudfront-logs"
# Note the new bucket name, e.g. "example-com-cf-logs-abcd1234"

# 4. Remove old logs bucket from state (does NOT delete from AWS)
terraform state rm 'module.redirect.module.cloudfront_logs_bucket[0]'

# 5. Apply - creates new bucket, updates CloudFront
terraform apply

# 6. Copy logs from old bucket to new
aws s3 cp --recursive s3://OLD-BUCKET s3://NEW-BUCKET

# 7. Delete old bucket when satisfied
aws s3 rb s3://OLD-BUCKET --force
```

### Approach B: Weighted DNS Migration (zero-downtime)

Best for production with compliance requirements (ISO 27001, SOC 2)
where no logging gaps are acceptable.

**Step 1** - Switch existing instance to weighted routing (keep old
version):

```hcl
module "redirect_old" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "1.3.1"   # keep your current pre-1.3.2 version
  # ... existing config unchanged ...
  dns_routing_policy = "weighted"
  dns_weight         = 255
  dns_set_identifier = "old"
}
```

`terraform apply` - traffic keeps flowing, routing policy changes.

**Step 2** - Add new 2.0.0 instance alongside (weight 0, no traffic):

```hcl
module "redirect_new" {
  source  = "registry.infrahouse.com/infrahouse/http-redirect/aws"
  version = "2.0.0"
  # ... same redirect_to, redirect_hostnames, zone_id ...
  dns_routing_policy             = "weighted"
  dns_weight                     = 0
  dns_set_identifier             = "new"
  create_certificate_dns_records = false  # old instance manages these
}
```

`terraform apply` - new infrastructure created, no traffic yet.

**Step 3** - Shift traffic. Set old weight to 0, new weight to 255:

```hcl
# In redirect_old:
  dns_weight = 0

# In redirect_new:
  dns_weight = 255
```

`terraform apply`

**Step 4** - Wait for DNS propagation and verify the old instance is no
longer receiving traffic. Route53 weighted record TTL is 60 seconds, but
downstream resolvers may cache longer.

```bash
# Check which CloudFront distribution DNS resolves to.
# Repeat until it consistently returns the NEW distribution domain.
dig +short YOUR-REDIRECT-DOMAIN

# Monitor the old CloudFront distribution for request activity.
# Wait until requests drop to zero.
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name Requests \
  --dimensions Name=DistributionId,Value=OLD-DISTRIBUTION-ID \
  --start-time $(date -u -v-10M +%Y-%m-%dT%H:%M:%S) \  # macOS
  # Linux: --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S)
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Sum
```

Once the old distribution shows zero requests for several minutes,
proceed.

**Step 5** - Copy logs from old bucket to new:

```bash
aws s3 cp --recursive s3://OLD-LOGS-BUCKET s3://NEW-LOGS-BUCKET
```

**Step 6** - Transfer DNS record ownership from old module to new module
using `terraform state mv`. This avoids a race condition where deleting
and recreating the same CAA records in one apply could fail.

**Warning**: State moves are delicate. Always verify exact resource
addresses before running `terraform state mv`, and run `terraform plan`
after each move to confirm no unexpected changes.

```bash
# First, list all DNS records in both modules to find exact addresses:
terraform state list | grep 'redirect_old.*route53'
terraform state list | grep 'redirect_new.*route53'

# Move CAA records. Repeat for each hostname prefix ("", "www", etc.):
terraform state mv \
  'module.redirect_old.aws_route53_record.caa_record[""]' \
  'module.redirect_new.aws_route53_record.caa_record[""]'

# Verify no unexpected changes after the move:
terraform plan

# Find exact ACM validation record addresses:
terraform state list | grep acm_validation

# Move ACM validation records:
terraform state mv \
  'module.redirect_old.aws_route53_record.acm_validation[...]' \
  'module.redirect_new.aws_route53_record.acm_validation[...]'

# Verify again:
terraform plan
```

Then flip the flag on the new module:

```hcl
# In redirect_new:
  create_certificate_dns_records = true
```

`terraform apply` - verify plan shows no changes to DNS records.

**Step 7** - Allow old logs bucket destruction, then remove old module:

```hcl
# In redirect_old, enable force destroy (bucket still has log files):
  cloudfront_logging_bucket_force_destroy = true
```

`terraform apply`

Then delete the `module "redirect_old"` block entirely.

`terraform apply` - destroys old CloudFront, old S3 buckets, old cert.

**Step 8** - Rename module in state and switch to simple routing:

```bash
terraform state mv module.redirect_new module.redirect
```

```hcl
module "redirect" {
  # ... remove weighted routing config or set:
  dns_routing_policy = "simple"
}
```

`terraform apply` - DNS records switch from weighted to simple.
