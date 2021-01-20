variable coordinator_data {
  type = object({
    domain = string
    lambda_source_bucket = string
    lambda_log_prefix = string
    cloudfront_log_prefix = string
    log_delivery_bucket = string
    log_partition_bucket = string
    scope = string
    domain_parts = object({
      top_level_domain = string
      controlled_domain_part = string
    })
  })
}

locals {
  lambda_logging_config = {
    debug = var.default_log_level
    bucket = var.coordinator_data.log_partition_bucket
    prefix = var.coordinator_data.lambda_log_prefix
  }
  cloudfront_logging_config = {
    bucket = var.coordinator_data.log_delivery_bucket
    prefix = var.coordinator_data.cloudfront_log_prefix
  }
}

variable site_bucket {
  type = string
}

variable trails_table {
  type = object({
    name = string
    permission_sets = object({
      read = list(object({
        actions = list(string)
        resources = list(string)
      }))
      write = list(object({
        actions = list(string)
        resources = list(string)
      }))
      delete_item = list(object({
        actions = list(string)
        resources = list(string)
      }))
    })
  })
}

// configuration vars
variable log_level {
  default = false
}

variable trails_updater_function_logging_config {
  type = list(object({
    bucket = string
    prefix = string
  }))
  default = []
}

variable default_log_level {
  type =  bool
  default = false
}

variable individual_log_levels {
  type = map(bool)
  default = {}
}

variable subject_alternative_names {
  type = list(string)
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

variable lambda_bucket {
  type = string
}

variable layer_arns {
  type = object({
    donut_days = string
    markdown_tools = string
  })
}

variable route53_zone_name {
  type = string
}

variable default_cloudfront_ttls {
  type = object({
    min = number
    default = number
    max = number
  })
  default = {
    min = 0
    default = 0
    max = 0
  }
}

variable site_description_content {
  type = string
}
