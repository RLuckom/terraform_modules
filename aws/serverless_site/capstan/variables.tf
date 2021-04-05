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

variable forbidden_website_paths {
  type = list(string)
  default = []
}

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

variable lambda_authorizers {
  type = map(object({
    name = string
    audience = list(string)
    issuer = string
    identity_sources = list(string)
  }))
  default = {}
}

variable lambda_origins {
  type = list(object({
    # This is going to be the origin_id in cloudfront. Should be a string
    # that suggests the function's purpose
    id = string
    # This should only be set to true if the access_control_function_qualified_arns
    # above are set AND you want the function access-controlled
    authorizer = string
    # unitary path denoting the function's endpoint, e.g.
    # "/meta/relations/trails"
    path = string
    # cloudfront routing pattern e.g.
    # "/meta/relations/trails*"
    site_path = string
    # apigateway path expression e.g.
    # "/meta/relations/trails/{trail+}"
    apigateway_path = string
    # Usually all lambdas in a dist should share one gateway, so the gway
    # name stems should be the same across all lambda endpoints.
    # But if you wanted multiple apigateways within a single dist., you
    # could set multiple name stems and the lambdas would get allocated
    # to different gateways
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
      # usually true
      query_string = bool
      # usually empty list
      query_string_cache_keys = any
      # probably best left to empty list; that way headers used for
      # auth can't be leaked by insecure functions. If there's
      # a reason to want certain headers, go ahead.
      headers = list(string)
      # same as headers; should generally be empty
      cookie_names = list(string)
    })
    lambda = object({
      arn = string
      name = string
    })
  }))
  default = []
}

variable no_cache_s3_path_patterns {
  type = list(object({
    path = string
    access_controlled = bool
  }))
  default = []
}

variable replication_time_limit {
  type = number
  default = 10
}

variable website_bucket_lambda_notifications {
  type = list(object({
    lambda_arn = string
    lambda_name = string
    lambda_role_arn = string
    events = list(string)
    filter_prefix = string
    filter_suffix = string
    permission_type = string
  }))
  default = []
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
  cloudfront_logging_config = {
    bucket = var.coordinator_data.cloudfront_log_delivery_bucket
    prefix = var.coordinator_data.cloudfront_log_delivery_prefix
  }
}

variable site_bucket {
  type = string
  default = null
}

variable subject_alternative_names {
  type = list(string)
  default = null
}

locals {
  subject_alternative_names = var.subject_alternative_names == null ? ["www.${local.routing.domain}"] : var.subject_alternative_names
  site_bucket = var.site_bucket == null ? replace(local.routing.domain, ".", "-") : var.site_bucket
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

variable website_bucket_prefix_object_permissions {
  type = list(object({
    permission_type = string
    prefix = string
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

variable asset_path {
  type = string
  default = ""
}
