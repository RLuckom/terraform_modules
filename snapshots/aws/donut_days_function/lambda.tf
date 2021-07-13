locals {
  base_source = [
    {
      file_name = "index.js"
      file_contents = file("${path.module}/src/s3_logging_generic_dd.js")
    },
    {
      file_name = "helpers/formatters.js"
      file_contents = file("${path.module}/src/formatters.js")
    },
    {
      file_name = "config.js"
      file_contents = var.config_contents
    }
  ]

  additional_helpers = [for helper in var.additional_helpers : 
  {
    file_name = "helpers/${trimsuffix(helper.helper_name, ".js")}.js"
    file_contents = helper.file_contents
  }]

  additional_dependency_helpers = [for helper in var.additional_dependency_helpers : 
  {
    file_name = "dependencyHelpers/${trimsuffix(helper.helper_name, ".js")}.js"
    file_contents = helper.file_contents
  }]
}

resource "random_id" "layer_suffix" {
  count = var.donut_days_layer.present ? 0 : 1
  byte_length = 8
}

module donut_days_layer {
  count = var.donut_days_layer.present ? 0 : 1
  source = "../layers/donut_days"
  layer_name = "donut_days_${random_id.layer_suffix[0].b64_url}"
}

module function {
  source = "../permissioned_lambda"
  unique_suffix = var.unique_suffix
  timeout_secs = var.timeout_secs
  account_id = var.account_id
  region = var.region
  mem_mb = var.mem_mb
  environment_var_map = merge({
    DONUT_DAYS_DEBUG = var.log_level
    LOG_BUCKET = var.logging_config.bucket
    LOG_PREFIX = var.logging_config.prefix
    METRIC_TABLE = var.logging_config.metric_table
    ACTION = var.action_name
    SCOPE = var.scope_name
  }, var.environment_var_map)
  invoking_principals = var.invoking_principals
  invoking_roles = var.invoking_roles
  self_invoke = var.self_invoke
  source_contents = concat(
    local.base_source,
    local.additional_dependency_helpers,
    local.additional_helpers,
  )
  lambda_event_configs = var.lambda_event_configs
  cron_notifications = var.cron_notifications
  queue_event_sources = var.queue_event_sources
  deny_cloudwatch = var.logging_config.bucket == "" ? false : false
  reserved_concurrent_executions = var.reserved_concurrent_executions
  lambda_details = {
    action_name = var.action_name
    scope_name = var.scope_name
    policy_statements = var.policy_statements
  }
  source_bucket = var.source_bucket
  layers = concat([
    var.donut_days_layer.present ? var.donut_days_layer : {
      present = true
      arn = module.donut_days_layer[0].layer.arn
    }
  ], var.additional_layers)
}
