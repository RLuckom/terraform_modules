module "replication_role" {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_role"
  count = local.need_replication_role ? 1 : 0
  role_name = "replicator-${var.scope}"
  role_policy = []
  principals = [{
    type = "Service"
    identifiers = ["s3.amazonaws.com"]
  }]
}

module "donut_days" {
  count = local.need_donut_days_layer ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/layers/donut_days"
}

module replication_lambda {
  count = local.need_replication_lambda ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  timeout_secs = var.replication_time_limit
  mem_mb = var.replication_memory_size
  config_contents = templatefile("${path.module}/src/config.js",
  {
    rules = jsonencode(local.manual_replication_rules)
    default_destination_bucket = var.default_destination_bucket_name
  })
  logging_config = var.logging_config
  lambda_event_configs = var.event_configs
  action_name = "${replace(var.name, "-", "_")}_repl"
  scope_name = var.security_scope
  donut_days_layer = local.donut_days_layer_config
}

locals {
  donut_days_layer_config = local.need_donut_days_layer ? module.donut_days[0].layer_config : var.replication_configuration.donut_days_layer
  auto_replication_role_arn = local.need_replication_role ? module.replication_role[0].role.arn : var.replication_configuration.role_arn
}
