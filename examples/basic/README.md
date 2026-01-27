# Basic HTTP Redirect Example

This example demonstrates the simplest use case: redirecting a domain and its www subdomain
to a new domain.

## What This Creates

- CloudFront distribution with TLS certificate
- S3 bucket for redirect origin
- Route 53 A/AAAA records
- ACM certificate (in us-east-1)

## Usage

1. Update the zone name in `main.tf` to your domain
2. Update `redirect_to` to your target domain
3. Run:

```bash
terraform init
terraform plan
terraform apply
```

## Redirect Behavior

| Source | Target |
|--------|--------|
| `https://example.com/` | `https://target.com/` |
| `https://www.example.com/` | `https://target.com/` |
| `https://example.com/page` | `https://target.com/page` |
| `https://example.com/page?query=1` | `https://target.com/page?query=1` |

## Cost

Estimated monthly cost: ~$1-5 for low traffic