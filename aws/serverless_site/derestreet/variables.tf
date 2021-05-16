variable system_id {
  type = object({
    security_scope = string
    subsystem_name = string
  })
}

variable account_id {
  type = string
}

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

variable user_email {
  type = string
}

variable plugin_static_configs {
  type = map(object({
    role_name_stem = string
    slug = string
  }))
  default = {}
}

variable plugin_configs {
  type = map(object({
    additional_connect_sources = list(string)
    policy_statements = list(object({
      actions = list(string)
      resources = list(string)
    }))
    plugin_relative_bucket_upload_permissions_needed = list(object({
      plugin_relative_key = string
      role_arn = string
      permission_type = string
    }))
    plugin_relative_bucket_list_permissions_needed = list(object({
      plugin_relative_key = string
      role_arn = string
    }))
    plugin_relative_bucket_host_permissions_needed = list(object({
      plugin_relative_key = string
      role_arn = string
      permission_type = string
    }))
    plugin_relative_lambda_origins = list(object({
      plugin_relative_path = string
      forwarded_headers = list(string)
      lambda = object({
        arn = string
        name = string
      })
    }))
    upload_path_lambda_notifications = list(object({
      lambda_arn = string
      lambda_name = string
      lambda_role_arn = string
      events = list(string)
      plugin_relative_filter_prefix = string
      filter_suffix = string
      permission_type = string
    }))
    storage_path_lambda_notifications = list(object({
      lambda_arn = string
      lambda_name = string
      lambda_role_arn = string
      events = list(string)
      plugin_relative_filter_prefix = string
      filter_suffix = string
      permission_type = string
    }))
    file_configs = list(object({
      content_type = string
      plugin_relative_key = string
      file_path = string
      file_contents = string
    }))
  }))
  default = {}
}

variable archive_system {
  type = object({
    bucket_permissions_needed = list(object({
      prefix = string
      permission_type = string
      arns = list(string) 
    }))
    lambda_notifications = list(object({
      filter_prefix = string
      filter_suffix = string
      lambda_arn = string
      lambda_arn = string
      lambda_role_arn = string
      lambda_name = string
      events = list(string)
      permission_type = string
    }))
  })
  default = {
    bucket_permissions_needed = []
    lambda_notifications = []
  }
}

variable subject_alternative_names {
  type = list(string)
  default = []
}

variable aws_sdk_layer {
  type = object({
    present = bool
    arn = string
  })
  default = {
    present = false
    arn = ""
  }
}

variable plugin_root {
  type = string
  default = "/plugins/"
}

variable api_root {
  type = string
  default = "/api/"
}

variable upload_root {
  type = string
  default = "/uploads/"
}

variable asset_hosting_root {
  type = string
  default = "/hosted-assets/"
}

variable forbidden_website_paths {
  type = list(string)
  default = ["uploads/"]
}

variable get_access_creds_path_for_lambda_origin {
  type = string
  default = "/api/actions/access/credentials"
}

module aws_sdk {
  count = local.need_aws_sdk_layer ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/layers/aws_sdk"
}

locals {
  gateway_name_stem = "default"
  plugin_root = trim(var.plugin_root, "/")
  api_root = trim(var.api_root, "/")
  upload_root = trim(var.upload_root, "/")
  asset_hosting_root = trim(var.asset_hosting_root, "/")
  need_aws_sdk_layer = var.aws_sdk_layer.present == false
  aws_sdk_layer_config = local.need_aws_sdk_layer ? module.aws_sdk[0].layer_config : var.aws_sdk_layer
  plugin_bucket_list_permissions_needed = zipmap(
    [for k in keys(var.plugin_configs) : replace(k, "/", "")],
    [for name, config in var.plugin_configs : 
        flatten([for permission in config.plugin_relative_bucket_list_permissions_needed : [
          {
            prefix = trimsuffix("${local.asset_hosting_root}/${local.plugin_root}/${replace(name, "/", "")}/${trim(permission.plugin_relative_key, "/")}", "/")
            arns = permission.role_arn == null ? [module.cognito_identity_management.authenticated_role[name].arn] : [permission.role_arn]
          },
        ]
      ])
  ])
  plugin_bucket_permissions_needed = zipmap(
    [for k in keys(var.plugin_configs) : replace(k, "/", "")],
    [for name, config in var.plugin_configs : 
    concat(
        [for permission in config.plugin_relative_bucket_upload_permissions_needed : {
        prefix = "${local.upload_root}/${local.plugin_root}/${replace(name, "/", "")}/${trim(permission.plugin_relative_key, "/")}/"
        permission_type = permission.permission_type
        arns = permission.role_arn == null ? [module.cognito_identity_management.authenticated_role[name].arn] : [permission.role_arn]
      }],
        [for permission in config.plugin_relative_bucket_host_permissions_needed : {
        prefix = "${local.asset_hosting_root}/${local.plugin_root}/${replace(name, "/", "")}/${trim(permission.plugin_relative_key, "/")}/"
        permission_type = permission.permission_type
        arns = permission.role_arn == null ? [module.cognito_identity_management.authenticated_role[name].arn] : [permission.role_arn]
      }]
    )
  ])
  route_to_function_names = flatten([for name, config in var.plugin_configs : [ for origin in config.plugin_relative_lambda_origins : {
    path = "/${local.api_root}/${local.plugin_root}/${replace(name, "/", "")}/${trim(origin.plugin_relative_path, "/")}"
    name = origin.lambda.name
  }]])
  route_to_function_name_map = zipmap(
    [ for entry in local.route_to_function_names : entry.path],
    [ for entry in local.route_to_function_names : entry.name]
  )
  plugin_configs = zipmap(
    [for k in keys(var.plugin_configs) : replace(k, "/", "")],
    [for name, config in var.plugin_configs : {
      role_name_stem = var.plugin_static_configs[name].role_name_stem
      slug = var.plugin_static_configs[name].slug
      additional_connect_sources = concat(
        config.additional_connect_sources,
        [ for origin in config.plugin_relative_lambda_origins :
          "https://${var.coordinator_data.routing.domain}/${local.plugin_root}/${replace(name, "/", "")}/${trim(origin.plugin_relative_path, "/")}"
        ]
      )
      policy_statements = config.policy_statements
      http_header_values = merge(
        {
          "Content-Security-Policy" = "default-src 'none'; style-src 'self'; script-src https://${var.coordinator_data.routing.domain}/${local.plugin_root}/${replace(name, "/", "")}/assets/js/; object-src 'none'; connect-src 'self' ${join(" ", concat(config.additional_connect_sources, [ for origin in config.plugin_relative_lambda_origins : "https://${var.coordinator_data.routing.domain}/${local.plugin_root}/${replace(name, "/", "")}/${trim(origin.plugin_relative_path, "/")}" ]))}; img-src 'self' data: blob:;"
        },
        var.default_static_headers
      )
      upload_prefix = "${local.upload_root}/${local.plugin_root}/${replace(name, "/", "")}/"
      asset_hosting_prefix = "${local.asset_hosting_root}/${local.plugin_root}/${replace(name, "/", "")}/"
      lambda_origins = [ for origin in config.plugin_relative_lambda_origins : {
        path = "/${local.api_root}/${local.plugin_root}/${replace(name, "/", "")}/${trim(origin.plugin_relative_path, "/")}"
        authorizer = "default"
        gateway_name_stem = local.gateway_name_stem
        allowed_methods = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
        cached_methods = ["GET", "HEAD"]
        compress = true
        ttls = {
          min = 0
          default = 0
          max = 0
        }
        forwarded_values = {
          query_string = true
          query_string_cache_keys = []
          headers = origin.forwarded_headers
          cookie_names = ["ID-TOKEN"]
        }
        lambda = {
          arn = module.apigateway_dispatcher.apigateway_dispatcher.lambda.arn
          name = module.apigateway_dispatcher.apigateway_dispatcher.lambda.function_name
        }
      }]
      upload_path_lambda_notifications = [for notification in config.upload_path_lambda_notifications : {
        filter_prefix = "${local.upload_root}/${local.plugin_root}/${replace(name, "/", "")}/${trim(notification.plugin_relative_filter_prefix, "/")}"
        filter_suffix = notification.filter_suffix
        lambda_arn = notification.lambda_arn
        lambda_arn = notification.lambda_arn
        lambda_role_arn = notification.lambda_role_arn
        lambda_name = notification.lambda_name
        events = notification.events
        permission_type = notification.permission_type
      }]
      storage_path_lambda_notifications = [for notification in config.storage_path_lambda_notifications : {
        filter_prefix = "${local.plugin_root}/${replace(name, "/", "")}/${trim(notification.plugin_relative_filter_prefix, "/")}"
        filter_suffix = notification.filter_suffix
        lambda_arn = notification.lambda_arn
        lambda_arn = notification.lambda_arn
        lambda_role_arn = notification.lambda_role_arn
        lambda_name = notification.lambda_name
        events = notification.events
        permission_type = notification.permission_type
      }]
      file_configs = [for file_config in config.file_configs : {
        content_type = file_config.content_type
        key = "${local.plugin_root}/${replace(name, "/", "")}/${file_config.plugin_relative_key}"
        file_path = file_config.file_path
        file_contents = file_config.file_contents
      }]
    }]
  )
}

variable additional_protected_domains {
  type = list(string)
  default = []
}

variable user_group_name {
  type = string
  default = "home_user_group"
}

variable default_static_headers {
  type = map(string)
  default = {
    "Strict-Transport-Security" = "max-age=31536000; includeSubdomains; preload"
    "Referrer-Policy" = "same-origin"
    "X-Frame-Options" = "DENY"
    "X-Content-Type-Options" = "nosniff"
  }
}

variable root_csp {
  type = string
  default = "default-src 'none'; style-src 'self'; object-src 'none'; img-src 'self' data:;"
}

variable archive_storage_class {
  type = string
  default = "GLACIER"
}

variable archive_tags {
  type = list(object({
    Key = string
    Value = string
  }))
  default = [{
    Key = "Archived"
    Value = "true"
  }]
}
