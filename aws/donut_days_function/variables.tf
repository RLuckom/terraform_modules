variable source_bucket {
  type = string
  default = ""
}

variable account_id {
  type = string
}

variable region {
  type = string
}

variable action_name {
  type = string
}

variable scope_name {
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

variable config_contents {
  type = string
  default = "module.exports = {}"
}

variable log_level {
  type = bool
  default = false
}

variable logging_config {
  type = object({
    bucket = string
    prefix = string
    metric_table = string
  })
  default = {
    bucket = ""
    prefix = ""
    metric_table = ""
  }
}

variable additional_layers {
  type = list(object({
    present = bool
    arn = string
  }))
  default = []
}

variable additional_helpers {
  type = list(object({
    file_contents = string
    helper_name = string
  }))
  default = []
}

variable additional_dependency_helpers {
  type = list(object({
    file_contents = string
    helper_name = string
  }))
  default = []
}

variable policy_statements {
  type = list(object({
    actions = list(string)
    resources = list(string)
  }))
  default = []
}

// passthrough args to permissioned_lambda

variable "invoking_principals" {
  type = list(object({
    service = string
    source_arn = string
  }))
  default = []
}

variable invoking_roles {
  type = list(string)
  default = []
}

variable "environment_var_map" {
  type = map(string)
  default = {}
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

variable "self_invoke" {
  type = object({
    allowed = bool
    concurrent_executions = number
  })
  default = {
    allowed = false
    concurrent_executions = 0
  }
}

variable "cron_notifications" {
  type = list(object({
    period_expression = string
  }))
  default = []
}

variable "queue_event_sources" {
  type = list(object({
    arn = string
    batch_size = number
  }))
  default = []
}

variable "timeout_secs" {
  type = number
  default = 10
}

variable "mem_mb" {
  type = number
  default = 256
}

variable "reserved_concurrent_executions" {
  type = number
  default = -1
}
