output "cert_arn" {
  value = aws_acm_certificate_validation.cert_validation.certificate_arn
}

output origin_access_identity {
  value = aws_cloudfront_origin_access_identity.cloudfront_logging_access_id
}
