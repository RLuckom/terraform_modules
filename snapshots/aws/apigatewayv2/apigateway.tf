data "aws_route53_zone" "selected" {
  count = length(var.domain_record) == 0 ? 0 : 1
  name = var.domain_record[0].zone_name
}

module "domain_cert" {
  count = length(var.domain_record) == 0 ? 0 : 1
  source = "../validated_cert"
  route53_zone_name = data.aws_route53_zone.selected[0].name
  domain_name = var.domain_record[0].domain_name
}

resource "aws_route53_record" "apigateway_domain" {
  count = length(var.domain_record) == 0 ? 0 : 1
  name = var.domain_record[0].domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.selected[0].zone_id

  alias {
    name                   = aws_apigatewayv2_domain_name.api_domain_name[0].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api_domain_name[0].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_apigatewayv2_domain_name" "api_domain_name" {
  count = length(var.domain_record) == 0 ? 0 : 1
  domain_name = var.domain_record[0].domain_name

  domain_name_configuration {
    certificate_arn = module.domain_cert[0].cert.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "api_mapping" {
  count = length(var.domain_record) == 0 ? 0 : 1
  api_id      = aws_apigatewayv2_api.api.id
  domain_name = aws_apigatewayv2_domain_name.api_domain_name[0].id
  stage       = aws_apigatewayv2_stage.stage.id 
}

resource "aws_apigatewayv2_api" "api" {
  name                       = "${var.name_stem}_api"
  protocol_type              = var.protocol
  route_selection_expression = var.route_selection_expression

  dynamic "cors_configuration" {
    for_each = var.cors_configuration
    content  {
      allow_credentials = cors_configuration.value.allow_credentials
      allow_headers = cors_configuration.value.allow_headers
      allow_methods = cors_configuration.value.allow_methods
      allow_origins = cors_configuration.value.allow_origins
      expose_headers = cors_configuration.value.expose_headers
      max_age = cors_configuration.value.max_age
    }
  }
}

resource "aws_cloudwatch_log_group" "apigateway_log_group" {
	name              = "/aws/apigateway/${aws_apigatewayv2_api.api.id}/${local.stage_name}"
	retention_in_days = var.log_retention_period
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id = aws_apigatewayv2_api.api.id
  name   = local.stage_name
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigateway_log_group.arn
    format = local.log_format
  }
}
