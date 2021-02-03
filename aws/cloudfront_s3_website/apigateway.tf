module "lambda_api_gateway" {
  count = length(local.apigateway_configs)
  source = "github.com/RLuckom/terraform_modules//aws/apigatewayv2"
  name_stem = local.apigateway_configs[count.index][0].gateway_name_stem
  system_id = var.system_id
  protocol = "HTTP"
  route_selection_expression = "$request.method $request.path"
  lambda_routes = [ for route in local.apigateway_configs[count.index]: 
    {
      route_key = "ANY ${route.apigateway_path}"
      handler_arn = route.lambda.arn
      handler_name = route.lambda.name
    }
  ]
}
