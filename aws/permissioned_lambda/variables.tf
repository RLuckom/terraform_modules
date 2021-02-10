variable lambda_details {
  type = object({
    action_name = string
    scope_name = string
    policy_statements = list(object({
      actions = list(string)
      resources = list(string)
    }))
  })
}

variable source_bucket {
  type = string
  default = ""
}

variable publish {
  default = false
}

locals {
  deployment_package_local_path = "${path.root}/functions/zip/${local.scoped_lambda_name}/lambda.zip"
  deployment_package_key = "${local.scoped_lambda_name}/lambda.zip"
  scoped_lambda_name = "${var.lambda_details.action_name}${var.lambda_details.scope_name == "" ? "" : "-"}${var.lambda_details.scope_name}"
}

variable invoking_principals {
  type = list(object({
    service = string
    source_arn = string
  }))
  default = []
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

variable self_invoke {
  type = object({
    allowed = bool
    concurrent_executions = number
  })
  default = {
    allowed = false
    concurrent_executions = 0
  }
}

variable layers {
  type = list(object({
    present = bool
    arn = string
  }))
  default = []
}

variable source_contents {
  type = list(object({
    file_contents = string
    file_name = string
  }))
  default = []
}

variable bucket_notifications {
  type = list(object({
    bucket = string
    events = list(string)
    filter_prefix = string
    filter_suffix = string
  }))
  default = []
}

variable cron_notifications {
  type = list(object({
    period_expression = string
  }))
  default = []
}

variable queue_event_sources {
  type = list(object({
    arn = string
    batch_size = number
  }))
  default = []
}

variable deny_cloudwatch {
  type = bool
  default = false
}

variable log_writer_policy {
  type = list(object({
    actions = list(string)
    resources = list(string)
  }))
  default = [{
    actions   =  [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*",
    ]
  }]
}

variable handler {
  type = string
  default = "index.handler"
}

variable timeout_secs {
  type = number
  default = 10
}

variable mem_mb {
  type = number
  default = 256
}

variable log_retention_period {
  type = number
  default = 7
}

variable reserved_concurrent_executions {
  type = number
  default = -1
}

variable environment_var_map {
  type = map(string)
  default = {
    NO_VARS = "true"
  }
}
