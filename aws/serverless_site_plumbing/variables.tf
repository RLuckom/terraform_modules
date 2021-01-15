// Identifying vars
variable purpose_descriptor {
  type = string
}

variable domain_parts {
  type = object({
    top_level_domain = string
    controlled_domain_part = string
  })
}

// state & permission vars
variable lambda_logging_bucket {
  type = string
}

variable site_logging_bucket {
  type = string
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
variable include_cookies_in_logging {
  default = false
}

variable debug {
  default = true
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
