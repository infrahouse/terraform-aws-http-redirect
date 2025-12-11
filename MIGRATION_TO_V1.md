# Migration Guide: Upgrading to v1.0.0

This guide helps you migrate from v0.x to v1.0.0 of the terraform-aws-http-redirect module.

## Overview of Breaking Changes

Version 1.0.0 introduces several breaking changes to improve the module's functionality and maintainability:

1. **DNS Records now use `for_each` instead of `count`** (task 2.4)
2. Provider alias requirement (completed in earlier tasks)
3. CloudFront cache policies replace deprecated `forwarded_values` (completed in earlier tasks)

## Breaking Change: DNS Records Migration (count → for_each)

### What Changed?

The module now uses `for_each` instead of `count` for DNS records (A, AAAA, and CAA records). This provides better Terraform state management and prevents resource recreation when reordering hostnames.

**Before (v0.x):**
```hcl
resource "aws_route53_record" "extra" {
  count   = length(var.redirect_hostnames)
  name    = local.redirect_domains[count.index]
  # ... rest of config
}
```

**After (v1.0.0):**
```hcl
resource "aws_route53_record" "extra" {
  for_each = local.redirect_domains_map
  name     = each.value
  # ... rest of config
}
```

### Impact

When upgrading, Terraform will want to destroy and recreate all DNS records because the resource addresses changed from:
- `aws_route53_record.extra[0]` → `aws_route53_record.extra[""]`
- `aws_route53_record.extra[1]` → `aws_route53_record.extra["www"]`
- etc.

### Migration Options

You have two options for migrating:

#### Option 1: Manual State Migration (Recommended for Production)

This option avoids DNS record recreation and downtime.

**Step 1:** Identify your current hostnames

If your `redirect_hostnames = ["", "www", "blog"]`, you need to migrate:
- Index `[0]` maps to `[""]` (apex domain)
- Index `[1]` maps to `["www"]`
- Index `[2]` maps to `["blog"]`

**Step 2:** Run state migration commands

```bash
# A records
terraform state mv 'module.redirect.aws_route53_record.extra[0]' 'module.redirect.aws_route53_record.extra[""]'
terraform state mv 'module.redirect.aws_route53_record.extra[1]' 'module.redirect.aws_route53_record.extra["www"]'
terraform state mv 'module.redirect.aws_route53_record.extra[2]' 'module.redirect.aws_route53_record.extra["blog"]'

# AAAA records
terraform state mv 'module.redirect.aws_route53_record.extra_aaaa[0]' 'module.redirect.aws_route53_record.extra_aaaa[""]'
terraform state mv 'module.redirect.aws_route53_record.extra_aaaa[1]' 'module.redirect.aws_route53_record.extra_aaaa["www"]'
terraform state mv 'module.redirect.aws_route53_record.extra_aaaa[2]' 'module.redirect.aws_route53_record.extra_aaaa["blog"]'

# CAA records
terraform state mv 'module.redirect.aws_route53_record.caa_record[0]' 'module.redirect.aws_route53_record.caa_record[""]'
terraform state mv 'module.redirect.aws_route53_record.caa_record[1]' 'module.redirect.aws_route53_record.caa_record["www"]'
terraform state mv 'module.redirect.aws_route53_record.caa_record[2]' 'module.redirect.aws_route53_record.caa_record["blog"]'
```

**Step 3:** Verify with terraform plan

```bash
terraform plan
```

You should see "No changes" or only minor updates (not DNS record recreation).

#### Option 2: Accept DNS Record Recreation (Simpler but with Downtime)

This option is simpler but causes brief DNS propagation delay.

**Step 1:** Update module version

```hcl
module "redirect" {
  source  = "infrahouse/http-redirect/aws"
  version = "1.0.0"  # Update from 0.x

  # ... rest of your config
}
```

**Step 2:** Run terraform apply TWICE

```bash
# First apply - may fail due to DNS timing issues
terraform apply -auto-approve

# Second apply - should succeed and complete the migration
terraform apply -auto-approve
```

**Why twice?** The first apply destroys old records and creates new ones. Due to DNS propagation timing, some records may conflict. The second apply completes any remaining migrations.

**Expected downtime:** 30-60 seconds of DNS propagation delay while records are recreated.

### Verification

After migration (either option), verify:

1. **Check Terraform state:**
   ```bash
   terraform state list | grep aws_route53_record
   ```

   You should see entries like:
   ```
   module.redirect.aws_route53_record.extra[""]
   module.redirect.aws_route53_record.extra["www"]
   module.redirect.aws_route53_record.extra_aaaa[""]
   module.redirect.aws_route53_record.extra_aaaa["www"]
   ```

2. **Verify DNS records work:**
   ```bash
   # Test redirect (replace with your domain)
   curl -I https://example.com
   ```

3. **Run terraform plan:**
   ```bash
   terraform plan
   ```
   Should show "No changes" or only expected updates.

## Example: Complete Migration for Default Configuration

For the default configuration with `redirect_hostnames = ["", "www"]`:

```bash
# Step 1: Backup state (recommended)
terraform state pull > terraform.tfstate.backup

# Step 2: Update module version in your Terraform code
# (Update version = "1.0.0" in your module block)

# Step 3: Run state migration
terraform state mv 'module.redirect.aws_route53_record.extra[0]' 'module.redirect.aws_route53_record.extra[""]'
terraform state mv 'module.redirect.aws_route53_record.extra[1]' 'module.redirect.aws_route53_record.extra["www"]'
terraform state mv 'module.redirect.aws_route53_record.extra_aaaa[0]' 'module.redirect.aws_route53_record.extra_aaaa[""]'
terraform state mv 'module.redirect.aws_route53_record.extra_aaaa[1]' 'module.redirect.aws_route53_record.extra_aaaa["www"]'
terraform state mv 'module.redirect.aws_route53_record.caa_record[0]' 'module.redirect.aws_route53_record.caa_record[""]'
terraform state mv 'module.redirect.aws_route53_record.caa_record[1]' 'module.redirect.aws_route53_record.caa_record["www"]'

# Step 4: Verify
terraform plan
# Should show "No changes" or only minor updates

# Step 5: Apply if needed
terraform apply
```

## Troubleshooting

### Issue: "Error: creating Route53 Record: it already exists"

**Cause:** DNS record from old state hasn't been fully deleted yet (DNS propagation timing).

**Solution:** Run `terraform apply` again. The second apply should succeed.

### Issue: "Error: No state migration needed"

**Cause:** You're already using v1.0.0 or the migration was already done.

**Solution:** Run `terraform plan` to verify current state. If no changes are shown, you're good.

### Issue: "Error: Invalid index" when running state mv

**Cause:** Resource doesn't exist at that index (check your actual `redirect_hostnames` configuration).

**Solution:**
1. Check your current state: `terraform state list | grep aws_route53_record`
2. Verify your `redirect_hostnames` variable matches the indices you're migrating

## Benefits of This Change

After migration, you'll benefit from:

- **Stable resource addresses:** Reordering `redirect_hostnames` won't destroy/recreate DNS records
- **Clearer state:** Resource addresses like `extra["www"]` are more readable than `extra[1]`
- **Better Terraform practices:** `for_each` is the recommended approach for managing multiple similar resources

## Need Help?

If you encounter issues during migration:

1. Check the [troubleshooting section](#troubleshooting) above
2. Review your Terraform state: `terraform state list`
3. Open an issue at https://github.com/infrahouse/terraform-aws-http-redirect/issues