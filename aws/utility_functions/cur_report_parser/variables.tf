variable account_id {
  type = string
}

variable region {
  type = string
}

variable io_config {
  type = object({
    input_config = object({
      bucket = string
      prefix = string
    })
    output_config = object({
      bucket = string
      prefix = string
    })
  })
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

variable action_name {
  type = string
  default = "cost_report_parser"
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

variable function_time_limit {
  type = number
  default = 10
}

variable function_memory_size {
  type = number
  default = 256
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
