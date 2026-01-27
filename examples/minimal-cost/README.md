# Minimal Cost Configuration Example

This example shows the lowest-cost configuration for HTTP redirects.

## Cost Optimizations

| Setting | Value | Savings |
|---------|-------|---------|
| `cloudfront_price_class` | `PriceClass_100` | ~30-50% vs global |
| `create_logging_bucket` | `false` | ~$0.50/month |

## Trade-offs

- **No access logging**: Not suitable for compliance requirements (ISO 27001, SOC 2)
- **Limited edge locations**: US, Canada, Europe only (higher latency for other regions)

## When to Use

- Personal domains
- Low-traffic redirects
- Development/testing environments
- Non-compliance-critical workloads

## Estimated Cost

~$1-2/month for low traffic (< 10,000 requests/month)

## Usage

```bash
terraform init
terraform plan
terraform apply
```