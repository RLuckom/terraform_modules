variable routing {
  type = object({
    domain_parts = object({
      top_level_domain = string
      controlled_domain_part = string
    })
    route53_zone_name = string
  })
}

variable system_id {
  type = object({
    security_scope = string
    subsystem_name = string
  })
}

variable access_control_function_qualified_arns {
  type = list(object({
    refresh_auth = string
    parse_auth = string
    check_auth = string
    sign_out = string
    http_headers = string
  }))
  default = []
}

variable secure_default_origin {
  type = bool
  default = true
}

variable enable_distribution {
  type = bool
  default = true
}

variable "subject_alternative_names" {
  type = list(string)
}

variable "allowed_origins" {
  type = list(string)
  default = []
}

variable "compress" {
  default = true
}

variable "no_cache_s3_path_patterns" {
  type = list(object({
    path = string
    access_controlled = bool
  }))
  default = []
}

variable "default_cloudfront_ttls" {
  type = object({
    min = number
    default = number
    max = number
  })
  default = {
    min = 0
    default = 3600
    max = 86400
  }
}

variable "lambda_origins" {
  type = list(object({
    id = string
    path = string
    site_path = string
    access_controlled = bool
    apigateway_path = string
    gateway_name_stem = string
    allowed_methods = list(string)
    cached_methods = list(string)
    compress = bool
    ttls = object({
      min = number
      default = number
      max = number
    })
    forwarded_values = object({
      query_string = bool
      query_string_cache_keys = any
      headers = list(string)
    })
    lambda = object({
      arn = string
      name = string
    })
  }))
  default = []
}

variable website_buckets {
  type = list(object({
    regional_domain_name = string
    origin_id = string
  }))
}

variable logging_config {
  type = object({
    bucket = string
    prefix = string
  })
  default = {
    bucket = ""
    prefix = ""
  }
}

variable log_cookies {
  type = bool
  default = false
}

locals {
  apigateway_names = distinct([ for origin in var.lambda_origins: origin.gateway_name_stem])
  apigateway_configs = [for gateway in distinct([ for origin in var.lambda_origins: origin.gateway_name_stem]) :
  [ for origin in var.lambda_origins: origin if origin.gateway_name_stem == gateway] ]
}

locals {
  routing = {
    domain_parts = var.routing.domain_parts
    route53_zone_name = var.routing.route53_zone_name
    domain = "${trimsuffix(var.routing.domain_parts.controlled_domain_part, ".")}.${trimprefix(var.routing.domain_parts.top_level_domain, ".")}"
  }
}
