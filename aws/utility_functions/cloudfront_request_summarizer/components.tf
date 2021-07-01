module donut_days {
  count = local.need_donut_days_layer ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/layers/donut_days"
}

module csv_parser {
  count = local.need_csv_parser_layer ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/layers/csv_parser"
}

module site_metric_summarizer {
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  account_id = var.account_id
  region = var.region
  cron_notifications = var.cron_notifications
  config_contents = templatefile("${path.module}/src/config.js",
  {
    athena_region = local.athena_region
    site_metric_configs = jsonencode(var.site_metric_configs)
  })
  additional_helpers = [{
    file_contents = file("${path.module}/src/parse_cloudfront_logs.js")
    helper_name = "parse_cloudfront_logs"
  }]
  logging_config = var.logging_config
  lambda_event_configs = var.lambda_event_configs
  action_name = var.action_name
  scope_name = var.security_scope
  donut_days_layer = local.donut_days_layer_config
  additional_layers = [
    local.csv_parser_layer_config
  ]
}

locals {
  athena_region = var.athena_region == "" ? var.region : var.athena_region
  need_donut_days_layer = var.donut_days_layer.present == false
  need_csv_parser_layer = var.csv_parser_layer.present == false
  donut_days_layer_config = local.need_donut_days_layer ? module.donut_days[0].layer_config : var.donut_days_layer
  csv_parser_layer_config = local.need_csv_parser_layer ? module.csv_parser[0].layer_config : var.csv_parser_layer
}
