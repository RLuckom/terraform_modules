variable coordinator_data {
  type = object({
    system_id = object({
      security_scope = string
      subsystem_name = string
    })
    routing = object({
      domain_parts = object({
        top_level_domain = string
        controlled_domain_part = string
      })
      domain = string
      route53_zone_name = string
    })
    // these can be set to "" if NA
    lambda_log_delivery_prefix = string
    lambda_log_delivery_bucket = string
    cloudfront_log_delivery_prefix = string
    cloudfront_log_delivery_bucket = string
  })
}

variable forbidden_website_paths {
  type = list(string)
  default = []
}

variable account_id {
  type = string
}

variable region {
  type = string
}

variable access_control_function_qualified_arns {
  type = list(object({
    refresh_auth = string
    parse_auth = string
    check_auth = string
    sign_out = string
    http_headers = string
    move_cookie_to_auth_header = string
  }))
  default = []
}

variable lambda_authorizer {
  type = object({
    name = string
    audience = list(string)
    issuer = string
    identity_sources = list(string)
  })
  default = {
    name = "NONE"
    audience = []
    issuer = ""
    identity_sources = []
  }
}

variable secure_default_origin {
  type = bool
  default = true
}

variable force_destroy {
  type = bool
  default = false
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
  trails_table_name = var.trails_table_name == null ? "${var.coordinator_data.system_id.security_scope}-${var.coordinator_data.system_id.subsystem_name}-trails_table" : var.trails_table_name
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
  site_bucket = var.site_bucket == null ? replace(local.routing.domain, ".", "-") : var.site_bucket
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

variable website_bucket_prefix_object_permissions {
  type = list(object({
    permission_type = string
    prefix = string
    arns = list(string)
  }))
  default = []
}

variable website_bucket_suffix_object_denials {
  type = list(object({
    permission_type = string
    suffix = string
    arns = list(string)
  }))
  default = []
}

variable website_bucket_bucket_permissions {
  type = list(object({
    permission_type = string
    arns = list(string)
  }))
  default = []
}

variable website_bucket_cors_rules {
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers = list(string)
    max_age_seconds = number
  }))
  default = []
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
