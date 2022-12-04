output cert_arn {
  value = aws_acm_certificate_validation.cert_validation.certificate_arn
}

output origin_access_identity {
  value = aws_cloudfront_origin_access_identity.cloudfront_access_id
}

output apigateways {
  value = [for gateway in module.lambda_api_gateway : {
    name = gateway.name
    stage_name = gateway.stage_name
  }]
}

output cloudfront_log_delivery_identity {
  value = aws_cloudfront_origin_access_identity.cloudfront_access_id
}

output routing {
  value = local.routing
}
