locals {
  s3_origin_id = local.routing.domain_parts.controlled_domain_part
}

resource "aws_cloudfront_origin_access_identity" "cloudfront_access_id" {
  comment = "access identity for cloudfront to ${local.routing.domain_parts.controlled_domain_part} bucket"
}

resource "aws_cloudfront_distribution" "website_distribution" {

  dynamic "origin" {
    for_each = var.website_buckets
    content {
      domain_name = origin.value.regional_domain_name
      origin_id   = origin.value.origin_id

      s3_origin_config {
        origin_access_identity = "origin-access-identity/cloudfront/${aws_cloudfront_origin_access_identity.cloudfront_access_id.id}"
      }
    }
  }

  dynamic "origin" {
    for_each = var.lambda_origins
    content {
      domain_name = trimprefix(module.lambda_api_gateway[index(local.apigateway_names, origin.value.gateway_name_stem)].api.api_endpoint, "https://")
      origin_id = origin.value.id
      // TODO: match module index to lambda origin
      origin_path = "/${module.lambda_api_gateway[0].stage_name}${origin.value.path}"

      custom_origin_config {
        http_port = 80
        https_port = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols = [ "TLSv1.2" ]
      }
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  dynamic "logging_config" {
    for_each = var.logging_config.bucket == "" ? [] : [var.logging_config]
    content {
      include_cookies = var.log_cookies
      bucket          = "${var.logging_config.bucket}.s3.amazonaws.com"
      prefix          = var.logging_config.prefix
    }
  }

  aliases = concat([local.routing.domain], var.subject_alternative_names)

  dynamic "ordered_cache_behavior" {
    for_each = var.lambda_origins
    content {
      path_pattern = ordered_cache_behavior.value.site_path
      target_origin_id = ordered_cache_behavior.value.id
      allowed_methods = ordered_cache_behavior.value.allowed_methods
      cached_methods = ordered_cache_behavior.value.cached_methods
      compress = ordered_cache_behavior.value.compress
      default_ttl = ordered_cache_behavior.value.ttls.default
      min_ttl = ordered_cache_behavior.value.ttls.min
      max_ttl = ordered_cache_behavior.value.ttls.max
      forwarded_values {
        query_string = ordered_cache_behavior.value.forwarded_values.query_string
        query_string_cache_keys = ordered_cache_behavior.value.forwarded_values.query_string_cache_keys
        headers = ordered_cache_behavior.value.forwarded_values.headers

        cookies {
          forward = "all"
        }
      }
      viewer_protocol_policy = "redirect-to-https"
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.no_cache_s3_path_patterns
    content {
      path_pattern = ordered_cache_behavior.value
      target_origin_id = local.s3_origin_id
      allowed_methods  = ["GET", "HEAD", "OPTIONS"]
      cached_methods   = ["GET", "HEAD"]
      compress = var.compress
      default_ttl = 0
      min_ttl = 0
      max_ttl = 0
      forwarded_values {
        query_string = false
        headers = ["Content-Type", "Access-Control-Request-Headers", "Access-Control-Request-Method", "Origin"]

        cookies {
          forward = "none"
        }
      }
      viewer_protocol_policy = "redirect-to-https"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    compress = var.compress

    forwarded_values {
      query_string = false
      headers = ["Content-Type", "Access-Control-Request-Headers", "Access-Control-Request-Method", "Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = var.default_cloudfront_ttls.min
    default_ttl            = var.default_cloudfront_ttls.default
    max_ttl                = var.default_cloudfront_ttls.max
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.cert_validation.certificate_arn
    minimum_protocol_version = "TLSv1"
    ssl_support_method = "sni-only"
  }
}
