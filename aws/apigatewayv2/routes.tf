resource "aws_apigatewayv2_route" "route" {
  count = length(var.lambda_routes)
  authorization_type = "NONE"
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
  configuration_sha = sha1(join(",", list(
                jsonencode(aws_apigatewayv2_integration.integration.*),
                      jsonencode(aws_apigatewayv2_route.route.*),
                      jsonencode(var.cors_configuration),
                      jsonencode(var.lambda_routes),
                          )))

}

resource "aws_lambda_permission" "lambda_permission" {
  count = length(var.lambda_routes)
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_routes[count.index].handler_name
  principal     = "apigateway.amazonaws.com"

  # The /*/*/* part allows invocation from any stage, method and resource path
  # within API Gateway REST API.
  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/${var.lambda_routes[count.index].route_key}"
}
