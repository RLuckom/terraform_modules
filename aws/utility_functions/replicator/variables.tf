variable action_name {
  type = string
  default = "replication"
}

variable logging_config {
  type = object({
    bucket = string
    prefix = string
  })
  default = {
    bucket = ""
    prefix = ""
  }
}

variable replication_time_limit {
  type = number
  default = 10
}

variable replication_memory_size {
  type = number
  default = 128
}

variable security_scope {
  type = string
  default = ""
}

variable donut_days_layer {
  type = object({
    present = bool
    arn = string
  })
  default = {
    present = false
    arn = ""
  }
}

variable lambda_event_configs {
  type = list(object({
    maximum_event_age_in_seconds = number
    maximum_retry_attempts = number
    on_success = list(object({
      function_arn = string
    }))
    on_failure = list(object({
      function_arn = string
    }))
  }))
  default = []
}

variable default_bucket_name {
  type = string
  default = ""
}

variable replication_configuration {
  type = object({
    role_arn = string
    donut_days_layer = object({
      present = string
      arn = string
    })
    rules = list(object({
      priority = number
      filter = object({
        prefix = string
        suffix = string
        tags = map(string)
      })
      enabled = bool
      replicate_delete = bool
      destination = object({
        bucket = string
        prefix = string
        manual = bool
      })
    }))
  })
  default = {
    role_arn = ""
    donut_days_layer = {
      present = false
      arn = ""
    }
    rules = []
  }
}

locals {
  manual_replication_rules = [for rule in var.replication_configuration.rules : rule if (rule.enabled && (rule.destination.prefix != "" || rule.destination.manual || rule.filter.suffix != "" || rule.destination.bucket == var.name || rule.destination.bucket == "" || rule.replicate_delete))]
  need_donut_days_layer = length(local.manual_replication_rules) > 0 && var.replication_configuration.donut_days_layer.present == false
  need_replication_lambda = length(local.manual_replication_rules) > 0
  lambda_notifications = concat(var.lambda_notifications, [for rule in local.manual_replication_rules : {
    lambda_arn = module.replication_lambda[0].lambda.arn
    lambda_name = module.replication_lambda[0].lambda.function_name
    events = rule.replicate_delete ? ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"] : ["s3:ObjectCreated:*"]
    filter_prefix = rule.filter.prefix == "" ? null : rule.filter.prefix
    filter_suffix = rule.filter.suffix == "" ? null : rule.filter.suffix
  }])
