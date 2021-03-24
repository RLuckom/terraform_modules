output get_access_creds {
  value = module.get_access_creds
}

output lambda_origins {
  value = [{
    # This is going to be the origin_id in cloudfront. Should be a string
    # that suggests the function's purpose
    id = "get_access_tokens"
    authorizer = var.authorizer_name
    # unitary path denoting the function's endpoint, e.g.
    # "/meta/relations/trails"
    path = var.api_path
    # cloudfront routing pattern e.g.
    # "/meta/relations/trails*"
    site_path = var.api_path
    # apigateway path expression e.g.
    # "/meta/relations/trails/{trail+}"
    apigateway_path = var.api_path
    # Usually all lambdas in a dist should share one gateway, so the gway
    # name stems should be the same across all lambda endpoints.
    # But if you wanted multiple apigateways within a single dist., you
    # could set multiple name stems and the lambdas would get allocated
    # to different gateways
    gateway_name_stem = var.gateway_name_stem
    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]
    compress = true
    ttls = {
      min = 0
      default = 0
      max = 0
    }
    forwarded_values = {
      # usually true
      query_string = true
      # usually empty list
      query_string_cache_keys = []
      # probably best left to empty list; that way headers used for
      # auth can't be leaked by insecure functions. If there's
      # a reason to want certain headers, go ahead.
      headers = []
      cookie_names = [var.id_token_name]
    }
    lambda = {
      arn = module.get_access_creds.lambda.arn
      name = module.get_access_creds.lambda.function_name
    }
  }]
}
