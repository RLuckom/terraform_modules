locals {
  s3_origin_id = var.domain_name_prefix
}

resource "aws_cloudfront_origin_access_identity" "cloudfront_logging_access_id" {
  comment = "access identity for cloudfront to ${var.domain_name_prefix} bucket"
}

resource "aws_cloudfront_distribution" "website_distribution" {
  origin {
    domain_name = module.website_bucket.bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/${aws_cloudfront_origin_access_identity.cloudfront_logging_access_id.id}"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = "${module.logging_bucket.bucket.id}.s3.amazonaws.com"
    prefix          = var.domain_name_prefix
  }

  aliases = concat([var.domain_name], var.subject_alternative_names)

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers = ["Access-Control-Request-Headers", "Access-Control-Request-Method", "Origin"]

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
