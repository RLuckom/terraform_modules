variable coordinator_data {
  type = object({
    lambda_log_delivery_prefix = string
    lambda_log_delivery_bucket = string
    cloudfront_log_delivery_prefix = string
    cloudfront_log_delivery_bucket = string
  })
  default = {
    lambda_log_delivery_prefix = ""
    lambda_log_delivery_bucket = ""
    cloudfront_log_delivery_prefix = ""
    cloudfront_log_delivery_bucket = ""
  }
}

variable routing {
  type = object({
    domain_parts = object({
      top_level_domain = string
      controlled_domain_part = string
    })
    scope = string
    route53_zone_name = string
  })
}

variable additional_allowed_origins {
  type = list(string)
  default = []
}

variable enable {
  default = true
}

locals {
  lambda_logging_config = {
    bucket = var.coordinator_data.lambda_log_delivery_bucket
    prefix = var.coordinator_data.lambda_log_delivery_prefix
  }
  cloudfront_logging_config = {
    bucket = var.coordinator_data.cloudfront_log_delivery_bucket
    prefix = var.coordinator_data.cloudfront_log_delivery_prefix
  }
}

variable site_bucket {
  type = string
}

variable trails_table_name {
  type = string
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
  default = ""
}

variable layers {
  type = object({
    donut_days = object({
      present = bool
      arn = string
    })
    markdown_tools = object({
      present = bool
      arn = string
    })
  })
  default = {
    donut_days = {
      present = false 
      arn = ""
    }
    markdown_tools = {
      present = false 
      arn = ""
    }
  }
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
  default = ""
}

variable site_title {
  type = string
  default = ""
}

variable maintainer {
  type = object({
    name = string
    email = string
  })
  default = {
    name = ""
    email = ""
  }
}

variable nav_links {
  type = list(object({
    name = string
    target = string
  }))
  default = []
}

variable asset_path {
  type = string
  default = ""
}
