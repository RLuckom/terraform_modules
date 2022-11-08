variable account_id {
  type = string
}

variable region {
  type = string
}

variable unique_suffix {
  type = string
  default = ""
}

variable action_name {
  type = string
  default = "error-relay"
}

variable function_time_limit {
  type = number
  default = 10
}

variable function_memory_size {
  type = number
  default = 128
}

variable security_scope {
  type = string
  default = ""
}

variable error_table_name {
  type = string
  default = ""
}

variable error_metric_ttl_days {
  type = number
  default = 90
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

variable slack_channel {
  type = string
  default = ""
}

variable slack_credentials_parameterstore_key {
  type = string
  default = ""
}

variable dynamo_error_table {
  type = string
  default = ""
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
