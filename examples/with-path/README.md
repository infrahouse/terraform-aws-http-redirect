# Redirect to Specific Path Example

This example demonstrates redirecting to a specific path on the target domain.

## Use Cases

- Service migration with path prefix
- Marketing campaign landing pages
- Product deprecation with redirect to docs

## Redirect Behavior

| Source | Target |
|--------|--------|
| `https://old-app.example.com/` | `https://new-app.example.com/migrated/` |
| `https://old-app.example.com/users` | `https://new-app.example.com/migrated/users` |
| `https://legacy.example.com/api?v=1` | `https://new-app.example.com/migrated/api?v=1` |

## Usage

```bash
terraform init
terraform plan
terraform apply
```