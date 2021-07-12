variable account_id {
  type = string
}

variable region {
  type = string
}

variable io_config {
  type = object({
    input_bucket = string
    input_path = string
    output_bucket = string
    output_path = string
    key_length = number
    tags = list(object({
      Key = string
      Value = string
    }))
  })
}

variable unique_suffix {
  type = string
  default = ""
}

variable image_layer {
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
  default = "image_proc"
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
