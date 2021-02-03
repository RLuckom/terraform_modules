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

variable system_id {
  type = object({
    security_scope = string
    subsystem_name = string
  })
}

variable routing {
  type = object({
    domain_parts = object({
      top_level_domain = string
      controlled_domain_part = string
    })
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
  default = null
}

variable trails_table_name {
  type = string
  default = null
}

locals {
  trails_table_name = var.trails_table_name == null ? "${var.system_id.security_scope}-${var.system_id.subsystem_name}-trails_table" : var.trails_table_name
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
  default = null
}

locals {
  subject_alternative_names = var.subject_alternative_names == null ? ["www.${local.routing.domain}"] : var.subject_alternative_names
  site_bucket = var.site_bucket == null ? local.routing.domain : var.site_bucket
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
  default = "Test Site"
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
