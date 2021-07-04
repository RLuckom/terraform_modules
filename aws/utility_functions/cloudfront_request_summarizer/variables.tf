variable athena_region {
  type = string
  default = ""
}

variable region {
  type = string
}

variable account_id {
  type = string
}

variable action_name {
  type = string
  default = "request_record_parser"
}

variable site_metric_configs {
  type = list(object({
    glue_db = string
    glue_table = string
    catalog = string
    result_location = string
    result_prefix = string
    data_prefix = string
  }))
  default = []
}

variable cron_notifications {
  type = list(object({
    period_expression = string
  }))
  default = [{
    period_expression = "cron(01 * * * ? *)"
  }]
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

variable csv_parser_layer {
  type = object({
    present = bool
    arn = string
  })
  default = {
    present = false
    arn = ""
  }
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

variable function_time_limit {
  type = number
  default = 30
}

variable function_memory_size {
  type = number
  default = 512
}

variable security_scope {
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
