module "lambda_api_gateway" {
  count = length(local.apigateway_configs)
  source = "../apigatewayv2"
  name_stem = local.apigateway_configs[count.index][0].gateway_name_stem
  system_id = var.system_id
  protocol = "HTTP"
  route_selection_expression = "$request.method $request.path"
  authorizers = var.lambda_authorizers
  lambda_routes = [ for route in local.apigateway_configs[count.index]: 
    {
      route_key = "ANY ${route.path}"
      handler_arn = route.lambda.arn
      handler_name = route.lambda.name
      authorizer = route.authorizer
    }
  ]
}
