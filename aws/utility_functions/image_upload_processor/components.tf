module donut_days {
  count = local.need_donut_days_layer ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/layers/donut_days"
}

module image_layer {
  count = local.need_image_layer ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/layers/image_dependencies"
}

module image_processing_lambda {
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  timeout_secs = var.function_time_limit
  mem_mb = var.function_memory_size
  config_contents = templatefile("${path.module}/src/config.js",
  {
    io_config = var.io_config
  })
  logging_config = var.logging_config
  lambda_event_configs = var.lambda_event_configs
  action_name = var.action_name
  scope_name = var.security_scope
  donut_days_layer = local.donut_days_layer_config
  additional_layers = [
    local.image_layer_config
  ]
}

locals {
  need_donut_days_layer = var.donut_days_layer.present == false
  need_image_layer = var.image_layer.present == false
  donut_days_layer_config = local.need_donut_days_layer ? module.donut_days[0].layer_config : var.donut_days_layer
  image_layer_config = local.need_image_layer ? module.image_layer[0].layer_config : var.image_layer
}
