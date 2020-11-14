output "api" {
  value = {
    name = aws_apigatewayv2_api.api.name
    id = aws_apigatewayv2_api.api.id
    arn = aws_apigatewayv2_api.api.arn
    api_endpoint = aws_apigatewayv2_api.api.api_endpoint
    execution_arn = aws_apigatewayv2_api.api.execution_arn
  }
}

output "api_deployment" {
  value = {
    id = aws_apigatewayv2_deployment.api.id
    api_id = aws_apigatewayv2_deployment.api.api_id
  }
}

output "api_stage" {
  value = {
    id = aws_apigatewayv2_stage.stage.id
    name = aws_apigatewayv2_stage.stage.name
    api_id = aws_apigatewayv2_stage.stage.api_id
  }
}

output permission_sets {
  value = {
    manage_connections = [{
      actions = [
        "execute-api:ManageConnections",
        "execute-api:Invoke"
      ],
      resources = [
        "${aws_apigatewayv2_api.api.execution_arn}/*"
      ]
    }]
  }
}
