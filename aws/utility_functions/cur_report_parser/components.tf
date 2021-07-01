module donut_days {
  count = local.need_donut_days_layer ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/layers/donut_days"
}

module csv_parser {
  count = local.need_csv_parser_layer ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/layers/csv_parser"
}

module cur_parser_lambda {
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  account_id = var.account_id
  region = var.region
  timeout_secs = var.function_time_limit
  mem_mb = var.function_memory_size
  config_contents = templatefile("${path.module}/src/config.js",
  {
    destination = var.io_config.output_config
    report_summary_key = local.report_summary_key
  })
  additional_helpers = [{
    file_contents = file("${path.module}/src/parse_report_utils.js")
    helper_name = "parse_report_utils"
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
  need_donut_days_layer = var.donut_days_layer.present == false
  need_csv_parser_layer = var.csv_parser_layer.present == false
  donut_days_layer_config = local.need_donut_days_layer ? module.donut_days[0].layer_config : var.donut_days_layer
  csv_parser_layer_config = local.need_csv_parser_layer ? module.csv_parser[0].layer_config : var.csv_parser_layer
}

