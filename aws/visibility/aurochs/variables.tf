variable cloudfront_delivery_bucket {
  type = string
  default = ""
}

variable visibility_data_bucket {
  type = string
  default = ""
}

variable athena_results_bucket {
  type = string
  default = ""
}

variable lambda_source_bucket {
  type = string
  default = ""
}

variable scopes {
  type = list(string)
  default = []
}

variable serverless_site_configs {
  type = map(object({
    top_level_domain = string
    controlled_domain_part = string
    scope = string
  }))
  default = {}
}

variable log_level {
  type =  bool
  default = false
}

variable donut_days_layer_arn {
  type = string
  default = ""
}

locals {
  lambda_logging_config = {
    bucket = local.visibility_data_bucket
    prefix = local.scoped_log_prefixes["default"].lambda_log_prefix
  }
}

locals {
  scopes = concat(["default"], var.scopes)
  cloudfront_delivery_bucket = var.cloudfront_delivery_bucket
  visibility_data_bucket = var.visibility_data_bucket
  athena_results_bucket = var.athena_results_bucket == "" ? var.visibility_data_bucket : var.athena_results_bucket
}

variable athena_prefix {
  type = string
  default = "athena"
}

variable athena_region {
  type = string
  default = "us-east-1"
}

variable cloudfront_prefix {
  type = string
  default = "cloudfront-logs"
}

variable lambda_prefix {
  type = string
  default = "lambda-logs"
}

variable expire_athena_results {
  type = object({
    enabled = bool
    expiration_days = number
  })
  default = {
    enabled = true
    expiration_days = 7 * 8
  }
}

variable expire_cloudfront_logs {
  type = object({
    enabled = bool
    expiration_days = number
  })
  default = {
    enabled = true
    expiration_days = 5 * 365
  }
}

variable expire_lambda_logs {
  type = object({
    enabled = bool
    expiration_days = number
  })
  default = {
    enabled = true
    expiration_days = 31 * 3
  }
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

data aws_caller_identity current {}

module column_schemas {
  source = "github.com/RLuckom/terraform_modules//aws/common_log_schemas"
}

locals {
  cloudfront_prefix = trim(var.cloudfront_prefix, "/")
  athena_prefix = trim(var.athena_prefix, "/")
  lambda_prefix = trim(var.lambda_prefix, "/")
}

locals {
  cloudfront_log_path_lifecycle_rules = [ for k, v in var.serverless_site_configs : {
    prefix = "${local.cloudfront_prefix}/domain=${trimsuffix(v.controlled_domain_part, ".")}.${trimprefix(v.top_level_domain, ".")}/"
    tags = {}
    enabled = var.expire_cloudfront_logs.enabled
    expiration_days = var.expire_cloudfront_logs.expiration_days
  }]
  lambda_log_path_lifecycle_rules = [ for scope in var.scopes : {
    prefix = "${local.lambda_prefix}/scope=${scope}/"
    tags = {}
    enabled = var.expire_lambda_logs.enabled
    expiration_days = var.expire_lambda_logs.expiration_days
  }]
  athena_result_path_lifecycle_rules = [{
    prefix = "${local.athena_prefix}/"
    tags = {}
    enabled = var.expire_athena_results.enabled
    expiration_days = var.expire_athena_results.expiration_days
  }]
  archive_function_destination_maps = {
    athena_destinations_map = zipmap(
      values(local.serverless_site_configs).*.cloudfront_log_delivery_prefix,
      values(local.serverless_site_configs).*.cloudfront_athena_result_location
    )
    log_destination_map = zipmap(
      values(local.serverless_site_configs).*.cloudfront_log_delivery_prefix,
      values(local.serverless_site_configs).*.cloudfront_log_storage_prefix
    )
    glue_table_map = zipmap(
      values(local.serverless_site_configs).*.cloudfront_log_delivery_prefix,
      values(local.serverless_site_configs).*.glue_table_name
    )
    glue_db_map = zipmap(
      values(local.serverless_site_configs).*.cloudfront_log_delivery_prefix,
      values(local.serverless_site_configs).*.glue_database_name
    )
  }
  archive_function_visibility_bucket_permissions = flatten(
    [
      [
        for site, config in local.serverless_site_configs : {
          permission_type = "put_object"
          prefix = config.cloudfront_log_storage_prefix
          arns = [
            module.archive_function.role.arn
          ]
        }
      ],
      [
        {
          permission_type = "put_object"
          prefix = local.scoped_log_prefixes["default"].lambda_log_prefix
          arns = [
            module.archive_function.role.arn
          ]
        }
      ],
    ]
  )
  archive_function_cloudfront_delivery_bucket_notifications = flatten(
    [
      [
        for site, config in local.serverless_site_configs : {
          permission_type = "move_known_objects_out"
          lambda_role_arn = module.archive_function.role.arn
          lambda_arn = module.archive_function.lambda.arn
          lambda_name = module.archive_function.lambda.function_name
          events = ["s3:ObjectCreated:*"]
          filter_prefix = config.cloudfront_log_delivery_prefix
          filter_suffix = ""
        }
      ],
    ]
  )
  scoped_log_prefixes = zipmap(
    local.scopes,
    [for scope in local.scopes : {
      lambda_log_prefix = "${local.lambda_prefix}/scope=${scope}/"
    }]
  )
  serverless_site_configs = zipmap(
    keys(var.serverless_site_configs),
    [ for k, v in var.serverless_site_configs : {
      domain = "${trimsuffix(v.controlled_domain_part, ".")}.${trimprefix(v.top_level_domain, ".")}"
      cloudfront_log_delivery_prefix = "${local.cloudfront_prefix}/${trimsuffix(v.controlled_domain_part, ".")}.${trimprefix(v.top_level_domain, ".")}/"
      cloudfront_log_storage_prefix = "${local.cloudfront_prefix}/domain=${trimsuffix(v.controlled_domain_part, ".")}.${trimprefix(v.top_level_domain, ".")}/"
      cloudfront_result_prefix = "${local.athena_prefix}/${local.cloudfront_prefix}/scope=${k}/"
      cloudfront_athena_result_location = "s3://${local.visibility_data_bucket}/${local.athena_prefix}/${local.cloudfront_prefix}/scope=${k}/"
      lambda_log_prefix = "${local.lambda_prefix}/scope=${k}/"
      lambda_result_prefix = "${local.athena_prefix}/${local.lambda_prefix}/scope=${k}/"
      lambda_athena_result_location = "s3://${local.visibility_data_bucket}/${local.athena_prefix}/${local.lambda_prefix}/scope=${k}"
      lambda_source_bucket = var.lambda_source_bucket
      log_delivery_bucket = local.cloudfront_delivery_bucket
      log_partition_bucket = local.visibility_data_bucket
      athena_result_bucket = local.visibility_data_bucket
      athena_region = var.athena_region
      glue_table_name = replace("${trimsuffix(v.controlled_domain_part, ".")}.${trimprefix(v.top_level_domain, ".")}", ".", "_")
      glue_database_name = replace("${k}-${local.visibility_data_bucket}", "-", "_")
      domain_parts = v
      scope = v.scope
    }]
  )
  data_warehouse_configs = zipmap(
    local.scopes,
    [ for scope in local.scopes : {
      lambda_log_prefix = "${local.lambda_prefix}/scope=${scope}/"
      log_delivery_bucket = local.cloudfront_delivery_bucket
      data_bucket = local.visibility_data_bucket
      glue_database_name = replace("${scope}-${local.visibility_data_bucket}", "-", "_")
      athena_region = var.athena_region
      scope = scope
      glue_table_configs = merge(zipmap(
        ["${scope}_lambda_logs"],  
        [{
          bucket_prefix = "${local.lambda_prefix}/scope=${scope}"
          skip_header_line_count = 0
          ser_de_info = {
            name                  = "json-ser-de"
            serialization_library = "org.openx.data.jsonserde.JsonSerDe"
            parameters = {
              "explicit.null"="true"
              "ignore.malformed.json"="true"
            }
          }
          columns = module.column_schemas.lambda_log_columns
          partition_keys = module.column_schemas.year_month_day_hour_partition_keys
        }]
      ),
      zipmap(
      [ for k, v in var.serverless_site_configs : replace("${trimsuffix(v.controlled_domain_part, ".")}.${trimprefix(v.top_level_domain, ".")}", ".", "_") if v.scope == scope],
      [ for k, v in var.serverless_site_configs : 
        {
          bucket_prefix = "${local.cloudfront_prefix}/domain=${trimsuffix(v.controlled_domain_part, ".")}.${trimprefix(v.top_level_domain, ".")}"
          skip_header_line_count = 2
          ser_de_info = {
            name                  = "cf_logs"
            serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
            parameters = {
              "field.delim"="\t"
              "serialization.format"="\t"
            }
          }
          columns = module.column_schemas.cloudfront_access_log_columns
          partition_keys = module.column_schemas.year_month_day_hour_partition_keys
        } if v.scope == scope]
      )
    )
    }]
  )
  lambda_log_configs = zipmap(
    local.scopes,
    [ for scope in local.scopes : {
      log_prefix = "${local.lambda_prefix}/scope=${scope}/"
      log_bucket = local.visibility_data_bucket
      source_bucket = var.lambda_source_bucket
      scope = scope
    }]
  )
}

locals {
  visibility_lifecycle_rules = concat(
    local.cloudfront_log_path_lifecycle_rules,
    local.lambda_log_path_lifecycle_rules,
    local.athena_result_path_lifecycle_rules
  )
}

output visibility_lifecycle_rules {
  value = concat(
    local.cloudfront_log_path_lifecycle_rules,
    local.lambda_log_path_lifecycle_rules,
    local.athena_result_path_lifecycle_rules
  )
}

variable scoped_logging_functions {
  type = map(map(object({
    permission_type = string
    role_arns = list(string)
  })))
  default = {}
}

variable scoped_athena_query_functions {
  type = map(map(list(string)))
  default = {}
}

variable glue_permission_name_map {
  type = map(map(object({
    add_partition_permission_names = list(string)
  })))
  default = {}
}

variable scoped_archive_notifications {
  type = map(map(object({
      lambda_arn = string
      lambda_name = string
      lambda_role_arn = string
      permission_type = string
      events              = list(string)
      filter_prefix       = string
      filter_suffix       = string
  })))
  default = {}
}

locals {
  visibility_prefix_object_permissions = flatten([
    for scope, v in var.scoped_logging_functions : [
      for prefix in [
        local.data_warehouse_configs[scope].lambda_log_prefix,
        local.serverless_site_configs[scope].cloudfront_log_storage_prefix
      ] : {
        prefix = prefix
        arns = lookup(v, prefix, {
          permission_type = ""
          role_arns = []
        }).role_arns 
        permission_type = lookup(v, prefix, {
          permission_type = ""
          role_arns = []
        }).permission_type 
      } if lookup(v, prefix, {
        permission_type = ""
        role_arns = []
      }).permission_type != ""
    ]
  ])
  archive_function_visibility_prefix_athena_query_permissions = [
    for k, config in local.serverless_site_configs : {
      prefix = config.cloudfront_result_prefix
      arns = [module.archive_function.role.arn]
    } 
  ]
  visibility_prefix_athena_query_permissions = flatten([
    for k, v in local.serverless_site_configs : [
      [ for scope, prefix_arns_map in var.scoped_athena_query_functions: [
        for prefix, arns in prefix_arns_map : {
          prefix = prefix
          arns = arns
      } if prefix == v.cloudfront_result_prefix ] if scope == v.scope]
    ]
  ])
}

output visibility_data_bucket {
  value = local.visibility_data_bucket
}

output athena_results_bucket {
  value = local.athena_results_bucket
}

output cloudfront_delivery_bucket {
  value = local.cloudfront_delivery_bucket
}

output data_warehouse_configs {
  value = local.data_warehouse_configs
}

output serverless_site_configs {
  value = local.serverless_site_configs
}

output lambda_source_bucket {
  value = var.lambda_source_bucket
}

output lambda_log_configs {
  value = local.lambda_log_configs
}
