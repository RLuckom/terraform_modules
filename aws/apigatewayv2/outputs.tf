output "api" {
  value = aws_apigatewayv2_api.api
}

output stage_name {
  value = local.stage_name
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
