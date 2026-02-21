resource "random_string" "this" {
  length  = 8
  special = false
  upper   = false
}

# Cache policy for redirect behavior
# Forwards query strings to preserve them in redirects
resource "aws_cloudfront_cache_policy" "redirect" {
  name        = "redirect-cache-policy-${random_string.this.result}"
  comment     = "Cache policy for HTTP redirect module"
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

# Security headers policy for redirect responses
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "redirect-security-headers-${random_string.this.result}"
  comment = "Security headers policy for HTTP redirect module"

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

resource "aws_cloudfront_distribution" "redirect" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = ""
  price_class         = var.cloudfront_price_class
  web_acl_id          = var.web_acl_id

  origin {
    domain_name = aws_s3_bucket_website_configuration.redirect.website_endpoint
    origin_id   = "redirect-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods = var.allow_non_get_methods ? [
      "GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"
    ] : ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "redirect-origin"
    viewer_protocol_policy     = "redirect-to-https"
    cache_policy_id            = aws_cloudfront_cache_policy.redirect.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    dynamic "function_association" {
      for_each = local.use_cloudfront_function ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.redirect[0].arn
      }
    }
  }

  # Logging enabled by default for compliance (ISO 27001, SOC 2)
  dynamic "logging_config" {
    for_each = var.create_logging_bucket ? [1] : []
    content {
      bucket          = local.cloudfront_logging_bucket
      include_cookies = var.cloudfront_logging_include_cookies
      prefix          = var.cloudfront_logging_prefix
    }
  }
  #
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.redirect.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
  #
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = local.redirect_domains
  tags = merge(
    local.default_module_tags,
    {
      module_version : local.module_version
    }
  )
}
