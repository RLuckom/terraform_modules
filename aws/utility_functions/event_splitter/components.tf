module "donut_days" {
  count = local.need_donut_days_layer ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/layers/donut_days"
}

module lambda {
  count = local.need_lambda ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  timeout_secs = var.time_limit
  mem_mb = var.memory_size
  config_contents = templatefile("${path.module}/src/config.js",
  {
    notifications = jsonencode(local.notifications)
  })
  logging_config = var.logging_config
  lambda_event_configs = var.lambda_event_configs
  action_name = var.action_name
  policy_statements = [{
    actions = ["lambda:InvokeFunction"]
    resources = local.distinct_lambda_arns
  }]
  scope_name = var.security_scope
  donut_days_layer = local.donut_days_layer_config
}

locals {
  donut_days_layer_config = local.need_donut_days_layer ? module.donut_days[0].layer_config : var.donut_days_layer
}
