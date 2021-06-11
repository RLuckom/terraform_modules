resource "aws_apigatewayv2_route" "route" {
  count = length(var.lambda_routes)
  authorization_type = var.lambda_routes[count.index].authorizer == "NONE" ? "NONE" : "JWT"
  authorizer_id = var.lambda_routes[count.index].authorizer == "NONE" ? null : aws_apigatewayv2_authorizer.jwt_auth[var.lambda_routes[count.index].authorizer].id
  api_id    = aws_apigatewayv2_api.api.id
  route_key = var.lambda_routes[count.index].route_key
  target = "integrations/${aws_apigatewayv2_integration.integration[count.index].id}"
}

resource "aws_apigatewayv2_integration" "integration" {
  count = length(var.lambda_routes)
  api_id    = aws_apigatewayv2_api.api.id
  integration_uri    = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${var.lambda_routes[count.index].handler_arn}/invocations"
  integration_type = "AWS_PROXY"
}
locals {
  configuration_sha = sha1(join(",", [
                jsonencode(aws_apigatewayv2_integration.integration.*),
                      jsonencode(aws_apigatewayv2_route.route.*),
                      jsonencode(var.cors_configuration),
                      jsonencode(var.lambda_routes),
                    ]))

}

resource "aws_apigatewayv2_authorizer" "jwt_auth" {
  for_each = var.authorizers
  api_id    = aws_apigatewayv2_api.api.id
  authorizer_type  = "JWT"
  identity_sources = each.value.identity_sources
  name             = each.key

  jwt_configuration {
    audience = each.value.audience
    issuer   = each.value.issuer 
  }
}

resource "aws_lambda_permission" "lambda_permission" {
  count = length(var.lambda_routes)
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_routes[count.index].handler_name
  principal     = "apigateway.amazonaws.com"

  # The /*/*/* part allows invocation from any stage, method and resource path
  # within API Gateway REST API.
  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
