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
  count = var.donut_days_layer_arn == null ? 1 : 0
  byte_length = 8
}

module donut_days_layer {
  count = var.donut_days_layer_arn == null ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/layers/donut_days"
  layer_name = "donut_days_${random_id.layer_suffix[0].b64_url}"
}

module function {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  timeout_secs = var.timeout_secs
  mem_mb = var.mem_mb
  environment_var_map = merge({
    DONUT_DAYS_DEBUG = var.logging_config.debug
    LOG_BUCKET = var.logging_config.bucket
    LOG_PREFIX = var.logging_config.prefix
    ACTION = var.action_name
    SCOPE = var.scope_name
  }, var.environment_var_map)
  invoking_principals = var.invoking_principals
  self_invoke = var.self_invoke
  source_contents = concat(
    local.base_source,
    local.additional_dependency_helpers,
    local.additional_helpers,
  )
  lambda_event_configs = var.lambda_event_configs
  bucket_notifications = var.bucket_notifications
  cron_notifications = var.cron_notifications
  queue_event_sources = var.queue_event_sources
  deny_cloudwatch = var.logging_config.bucket == "" ? false : false
  reserved_concurrent_executions = var.reserved_concurrent_executions
  lambda_details = {
    action_name = var.action_name
    scope_name = var.scope_name
    bucket = var.source_bucket
    policy_statements = var.policy_statements
  }
  layers = concat([
    var.donut_days_layer_arn == null ? module.donut_days_layer[0].layer.arn : var.donut_days_layer_arn,
  ], var.additional_layers)
}
