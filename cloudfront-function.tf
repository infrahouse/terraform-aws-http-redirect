# CloudFront Function to handle redirects for all HTTP methods.
# When allow_non_get_methods is enabled, this function intercepts all requests
# at the viewer-request stage and returns the appropriate redirect response.
#
# GET/HEAD use the standard redirect code (301 or 302).
# Other methods (POST, PUT, DELETE, PATCH) use the method-preserving
# equivalent (308 or 307) so clients resend the request body with the
# same method to the new location.

resource "aws_cloudfront_function" "redirect" {
  count = local.use_cloudfront_function ? 1 : 0

  name    = "redirect-all-methods-${data.aws_route53_zone.redirect.zone_id}"
  runtime = "cloudfront-js-2.0"
  comment = "Redirect all HTTP methods for ${var.redirect_to}"
  publish = true

  code = templatefile("${path.module}/templates/redirect-all-methods.js.tftpl", {
    redirect_hostname    = local.redirect_hostname
    redirect_path        = local.redirect_path != null ? local.redirect_path : ""
    get_head_status_code = var.permanent_redirect ? 301 : 302
    other_status_code    = var.permanent_redirect ? 308 : 307
    response_headers     = var.response_headers
  })
}
