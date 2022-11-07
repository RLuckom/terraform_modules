locals {
  need_donut_days_layer = var.donut_days_layer.present == false
  donut_days_layer_config = local.need_donut_days_layer ? module.donut_days[0].layer_config : var.donut_days_layer
}

module "donut_days" {
  count = local.need_donut_days_layer ? 1 : 0
  source = "../../layers/donut_days"
}

module "error_relay" {
  source = "../../permissioned_lambda"
  timeout_secs = var.function_time_limit
  account_id = var.account_id
  region = var.region
  mem_mb = var.function_memory_size
  unique_suffix = var.unique_suffix
  environment_var_map = {
    SLACK_CREDENTIAL_PARAM = var.slack_credentials_parameterstore_key
    SLACK_CHANNEL = var.slack_channel
    ERROR_TABLE = var.dynamo_error_table
  }
  source_contents = [
    {
      file_name = "index.js"
      file_contents = file("${path.module}/src/index.js")
    },
  ]
  lambda_details = {
    action_name = var.action_name
    scope_name = var.security_scope
    policy_statements = concat(
      local.read_slack_credentials_permissions
    )
  }
  layers = [local.donut_days_layer_config]
}

locals {
  read_slack_credentials_permissions = [{
    actions = [ "ssm:GetParameter" ]
    resources = [
      "arn:aws:ssm:${var.region}:${var.account_id}:parameter${var.slack_credentials_parameterstore_key}"
    ]
  }]
  notify_failure_and_success = [
    {
      maximum_event_age_in_seconds = 60
      maximum_retry_attempts = 2
      on_success = [{
        function_arn = module.error_relay.lambda.arn
      }]
      on_failure = [{
        function_arn = module.error_relay.lambda.arn
      }]
    }
  ]
  notify_failure_only = [
    {
      maximum_event_age_in_seconds = 60
      maximum_retry_attempts = 2
      on_success = []
      on_failure = [{
        function_arn = module.error_relay.lambda.arn
      }]
    }
  ]
  notify_success_only = [
    {
      maximum_event_age_in_seconds = 60
      maximum_retry_attempts = 2
      on_success = []
      on_failure = [{
        function_arn = module.error_relay.lambda.arn
      }]
    }
  ]
}
