# Plan for Issue #30: Support HTTP redirects for POST and other non-GET methods

## Problem

CloudFront's `allowed_methods` is `["GET", "HEAD"]` which returns 403 for other methods.
Even if allowed, S3 website hosting returns 405 for non-GET methods.

## Solution: CloudFront Function

Use a **CloudFront Function** (viewer-request) to handle all redirect logic when
`allow_non_get_methods = true`. This replaces the S3 origin approach for that mode:

### 1. New file `cloudfront-function.tf`

CloudFront Function that:
- Uses the configured redirect status code for GET/HEAD
- Uses the method-preserving equivalent for POST/PUT/DELETE/PATCH
- Preserves query strings and paths
- Constructs the Location header with redirect_to hostname + path

Redirect status code mapping:

| `permanent_redirect` | GET/HEAD | POST/PUT/DELETE/PATCH |
|----------------------|----------|----------------------|
| `true` (default)     | 301      | 308                  |
| `false`              | 302      | 307                  |

- **true (default)**: Permanent redirect. Browsers cache it. Best for SEO/domain migrations.
  Non-GET methods use 308 (permanent + method-preserving).
- **false**: Temporary redirect. Not cached. Good for maintenance/A/B testing.
  Non-GET methods use 307 (temporary + method-preserving).

### 2. New variables

#### `allow_non_get_methods`
- Type: `bool`
- Default: `false`
- Enables redirects for POST, PUT, DELETE, PATCH, and OPTIONS methods
  (in addition to GET and HEAD which are always supported)

#### `permanent_redirect`
- Type: `bool`
- Default: `true` (matches current 301 behavior)
- Controls whether redirects are permanent or temporary
- Description must document the actual HTTP status codes returned:

| `permanent_redirect` | GET/HEAD | POST/PUT/DELETE/PATCH |
|----------------------|----------|----------------------|
| `true` (default)     | 301      | 308                  |
| `false`              | 302      | 307                  |

### 3. Update `main.tf`

- Conditionally set `allowed_methods` to all methods when enabled
- Add `function_association` for viewer-request when enabled
- When function handles redirects, we still need an origin (CloudFront requires one),
  but the function short-circuits before hitting it

### 4. S3 resources remain

CloudFront requires an origin even if the function handles the response. The S3 origin
acts as a fallback but the CloudFront Function intercepts all requests.

### 5. Update test data and tests

#### Test data changes
- Add `allow_non_get_methods` and `permanent_redirect` variables to `test_data/main/`
- Pass them through to the module in `test_data/main/main.tf`

#### New test: `test_non_get_methods`
- Parametrized by AWS provider version (5, 6) like existing tests
- Parametrized by redirect_to (hostname only, hostname/path) like existing tests
- Sets `allow_non_get_methods = true`
- Test cases:
  1. **POST redirect**: Send POST request, verify 308 status code,
     verify Location header has correct target, verify path preserved
  2. **POST with query string**: Send POST with query params,
     verify query strings preserved in Location header
  3. **GET still works**: Verify GET still returns 301 (not broken by the change)

#### Existing tests
- Existing `test_module` remains unchanged (exercises the default
  `allow_non_get_methods = false` path, backward compatibility)

### 6. Run `terraform fmt`

For formatting compliance.

## Backward Compatibility

- Default `allow_non_get_methods = false` means no behavior change
- Existing deployments unaffected