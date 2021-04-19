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

// If any of the supported systems use the same
// security_scope as the visibility system, bad things will happen
variable visibility_system_id {
  type = object({
    security_scope = string
    subsystem_name = string
  })
  default = {
    security_scope = "visibility"
    subsystem_name = "visibility"
  }
}

// The distinction between supported_system_definitions and supported_system_clients
// is entirely about breaking cycles. They must mirror each other to some extent, but
// the definitions are used to build the names of things, which are later depended on
// (outside of this module) to create the client resources listed in supported_system_clients.
// If these were combined into a single struct, it would create cycles between the system names
// and the client resources.
variable supported_system_definitions {
  type = map(object({
    subsystems = map(object({
      serverless_site_configs = map(object({
        route53_zone_name = string
        domain_parts = object({
          top_level_domain = string
          controlled_domain_part = string
        })
      }))
    }))
  }))
  default = {}
}

variable supported_system_clients {
  type = map(object({
    subsystems = map(object({
      glue_permission_name_map = object({
        add_partition_permission_names = list(string)
        add_partition_permission_arns = list(string)
        query_permission_names = list(string)
        query_permission_arns = list(string)
      })
      scoped_logging_functions = list(string)
    }))
  }))
  default = {}
}

locals {
  systems_with_subsystems = [ for sys_name, sys_config in var.supported_system_definitions : {
    security_scope = sys_name
    subsystem_names = keys(sys_config.subsystems)
  }]
  serverless_site_config_map = merge(flatten(
    [for security_scope, scope_config in var.supported_system_definitions :
      [ for subsystem_name, subsystem_config in scope_config.subsystems : zipmap(
        keys(subsystem_config.serverless_site_configs),
        [ for site_name, site_config in subsystem_config.serverless_site_configs : {
          domain_parts = site_config.domain_parts
          route53_zone_name = site_config.route53_zone_name
          system_id = {
            security_scope = security_scope
            subsystem_name = subsystem_name
          }
        }])
      ]
    ]
  )...)
}

variable log_level {
  type =  bool
  default = false
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

locals {
  lambda_logging_config = {
    bucket = local.visibility_data_bucket
    prefix = local.scoped_log_prefixes[var.visibility_system_id.security_scope][var.visibility_system_id.subsystem_name].lambda_log_prefix
  }
}

locals {
  system_ids = concat([{
    subsystem_names = [var.visibility_system_id.subsystem_name]
    security_scope = var.visibility_system_id.security_scope
  }], local.systems_with_subsystems)
  cloudfront_delivery_bucket = var.cloudfront_delivery_bucket
  visibility_data_bucket = var.visibility_data_bucket
  athena_results_bucket = var.athena_results_bucket == "" ? var.visibility_data_bucket : var.athena_results_bucket
}

variable athena_prefix {
  type = string
  default = "source=athena"
}

variable athena_delivery_prefix {
  type = string
  default = "athena"
}

variable athena_region {
  type = string
  default = "us-east-1"
}

variable cloudfront_prefix {
  type = string
  default = "source=cloudfront"
}

variable cloudfront_delivery_prefix {
  type = string
  default = "cloudfront"
}

variable lambda_prefix {
  type = string
  default = "source=lambda"
}

variable lambda_delivery_prefix {
  type = string
  default = "lambda"
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
  cloudfront_delivery_prefix = trim(var.cloudfront_delivery_prefix, "/")
  athena_delivery_prefix = trim(var.athena_delivery_prefix, "/")
  lambda_delivery_prefix = trim(var.lambda_delivery_prefix, "/")
  cloudfront_prefix = trim(var.cloudfront_prefix, "/")
  athena_prefix = trim(var.athena_prefix, "/")
  lambda_prefix = trim(var.lambda_prefix, "/")
}

locals {
  cloudfront_log_path_lifecycle_rules = [ for k, v in local.serverless_site_config_map : {
    prefix = "security_scope=${v.system_id.security_scope}/subsystem=${v.system_id.subsystem_name}/${local.cloudfront_prefix}/domain=${trimsuffix(v.domain_parts.controlled_domain_part, ".")}.${trimprefix(v.domain_parts.top_level_domain, ".")}/"
    tags = {}
    enabled = var.expire_cloudfront_logs.enabled
    expiration_days = var.expire_cloudfront_logs.expiration_days
  }]
  lambda_log_path_lifecycle_rules = flatten(
    [ for system_id in local.system_ids : 
    [ for subsystem_name in system_id.subsystem_names : {
      prefix = "security_scope=${system_id.security_scope}/subsystem=${subsystem_name}/${local.lambda_prefix}/"
      tags = {}
      enabled = var.expire_lambda_logs.enabled
      expiration_days = var.expire_lambda_logs.expiration_days
    }]]
  )
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
          prefix = local.scoped_log_prefixes[var.visibility_system_id.security_scope][var.visibility_system_id.subsystem_name].lambda_log_prefix
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
    local.system_ids.*.security_scope,
    [for system_id in local.system_ids : 
    zipmap(
      system_id.subsystem_names,
      [for subsystem_name in system_id.subsystem_names : {
        lambda_log_prefix = "security_scope=${system_id.security_scope}/subsystem=${subsystem_name}/${local.lambda_prefix}/"
      }]
    )]
  )
  empty_system_client = {
    subsystems = {}
  }
  serverless_site_configs = zipmap(
    keys(local.serverless_site_config_map),
    [ for k, v in local.serverless_site_config_map : {
      cloudfront_log_delivery_prefix = "${local.cloudfront_delivery_prefix}/${trimsuffix(v.domain_parts.controlled_domain_part, ".")}.${trimprefix(v.domain_parts.top_level_domain, ".")}/"
      cloudfront_log_storage_prefix = "security_scope=${v.system_id.security_scope}/subsystem=${v.system_id.subsystem_name}/${local.cloudfront_prefix}/domain=${trimsuffix(v.domain_parts.controlled_domain_part, ".")}.${trimprefix(v.domain_parts.top_level_domain, ".")}/"
      cloudfront_result_prefix = "security_scope=${v.system_id.security_scope}/subsystem=${v.system_id.subsystem_name}/${local.athena_prefix}/${local.cloudfront_prefix}/"
      cloudfront_athena_result_location = "s3://${local.visibility_data_bucket}/security_scope=${v.system_id.security_scope}/subsystem=${v.system_id.subsystem_name}/${local.athena_prefix}/${local.cloudfront_prefix}/"
      lambda_log_prefix = "security_scope=${v.system_id.security_scope}/subsystem=${v.system_id.subsystem_name}/${local.lambda_prefix}/"
      lambda_log_delivery_prefix = "security_scope=${v.system_id.security_scope}/subsystem=${v.system_id.subsystem_name}/${local.lambda_prefix}/"
      lambda_result_prefix = "security_scope=${v.system_id.security_scope}/subsystem=${v.system_id.subsystem_name}/${local.athena_prefix}/${local.lambda_prefix}/"
      lambda_athena_result_location = "s3://${local.visibility_data_bucket}/security_scope=${v.system_id.security_scope}/subsystem=${v.system_id.subsystem_name}/${local.athena_prefix}/${local.lambda_prefix}/"
      lambda_source_bucket = var.lambda_source_bucket
      log_delivery_bucket = local.cloudfront_delivery_bucket
      cloudfront_log_delivery_bucket = local.cloudfront_delivery_bucket
      log_partition_bucket = local.visibility_data_bucket
      lambda_log_delivery_bucket = local.visibility_data_bucket
      athena_result_bucket = local.visibility_data_bucket
      athena_region = var.athena_region
      glue_table_name = replace("${trimsuffix(v.domain_parts.controlled_domain_part, ".")}.${trimprefix(v.domain_parts.top_level_domain, ".")}", ".", "_")
      glue_database_name = replace("${v.system_id.security_scope}-${local.visibility_data_bucket}", "-", "_")
      routing = {
        domain = "${trimsuffix(v.domain_parts.controlled_domain_part, ".")}.${trimprefix(v.domain_parts.top_level_domain, ".")}"
        domain_parts = v.domain_parts
        route53_zone_name = v.route53_zone_name
      }
      system_id = v.system_id
      security_scope = v.system_id.security_scope
      subsystem_name = v.system_id.subsystem_name
    }]
  )
  data_warehouse_configs = zipmap(
    local.system_ids.*.security_scope,
    [for system_id in local.system_ids : {
      log_delivery_bucket = local.cloudfront_delivery_bucket
      data_bucket = local.visibility_data_bucket
      glue_database_name = replace("${system_id.security_scope}-${local.visibility_data_bucket}", "-", "_")
      athena_region = var.athena_region
      security_scope = system_id.security_scope
      glue_table_configs = merge(zipmap(
        [for subsystem_name in system_id.subsystem_names : "${subsystem_name}_lambda_logs"],
        [for subsystem_name in system_id.subsystem_names : {
          bucket_prefix = "security_scope=${system_id.security_scope}/subsystem=${subsystem_name}/${local.lambda_prefix}"
          result_prefix = "security_scope=${system_id.security_scope}/subsystem=${subsystem_name}/${local.athena_prefix}/${local.lambda_prefix}/"
          subsystem_name = subsystem_name
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
        [ for k, v in local.serverless_site_config_map : replace("${trimsuffix(v.domain_parts.controlled_domain_part, ".")}.${trimprefix(v.domain_parts.top_level_domain, ".")}", ".", "_") if v.system_id.security_scope == system_id.security_scope],
        [ for k, v in local.serverless_site_config_map : 
        {
          bucket_prefix = "security_scope=${v.system_id.security_scope}/subsystem=${v.system_id.subsystem_name}/${local.cloudfront_prefix}/domain=${trimsuffix(v.domain_parts.controlled_domain_part, ".")}.${trimprefix(v.domain_parts.top_level_domain, ".")}"
          result_prefix = "security_scope=${v.system_id.security_scope}/subsystem=${v.system_id.subsystem_name}/${local.athena_prefix}/${local.cloudfront_prefix}/"
          subsystem_name = v.system_id.subsystem_name
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
        } if v.system_id.security_scope == system_id.security_scope]
      )
    )}]
  )
  lambda_log_configs = zipmap(
    local.system_ids.*.security_scope,
    [for system_id in local.system_ids : 
    zipmap(
      system_id.subsystem_names,
      [for subsystem_name in system_id.subsystem_names : {
        log_prefix = "security_scope=${system_id.security_scope}/subsystem=${subsystem_name}/${local.lambda_prefix}/"
        log_bucket = local.visibility_data_bucket
        config = {
          prefix = "security_scope=${system_id.security_scope}/subsystem=${subsystem_name}/${local.lambda_prefix}/"
          bucket = local.visibility_data_bucket
        }
        system_id = {
          security_scope = system_id.security_scope
          subsystem_name = subsystem_name
        }
        source_bucket = var.lambda_source_bucket
        security_scope = system_id.security_scope
        subsystem_name = subsystem_name
      }]
    )]
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

variable glue_permission_name_map {
  type = map(map(object({
    add_partition_permission_names = list(string)
    query_permission_names = list(string)
    add_partition_permission_arns = list(string)
    query_permission_arns = list(string)
  })))
  default = {}
}

locals {
  visibility_prefix_object_permissions = flatten([
    for security_scope, system_config in var.supported_system_clients : [
      for subsystem_name, subsystem_config in system_config.subsystems : [
        {
          prefix = local.lambda_log_configs[security_scope][subsystem_name].log_prefix,
          arns = subsystem_config.scoped_logging_functions
          permission_type = "put_object"
        }
      ]
    ]
  ])
  archive_function_visibility_prefix_athena_query_permissions = [
    for k, config in local.serverless_site_configs : {
      result_prefix = config.cloudfront_result_prefix
      log_storage_prefix = config.cloudfront_log_storage_prefix
      arns = [module.archive_function.role.arn]
    } 
  ]
  visibility_prefix_athena_query_permissions = flatten([
    for security_scope, system_config in var.supported_system_clients : [
      for subsystem_name, subsystem_config in system_config.subsystems : [
        for table_name, table_map in local.data_warehouse_configs[security_scope].glue_table_configs: {
          log_storage_prefix = table_map.bucket_prefix
          result_prefix = table_map.result_prefix
          arns = concat(subsystem_config.glue_permission_name_map.add_partition_permission_arns, subsystem_config.glue_permission_name_map.query_permission_arns)
        }
        if length(concat(subsystem_config.glue_permission_name_map.add_partition_permission_arns, subsystem_config.glue_permission_name_map.query_permission_arns)) > 0
      ]
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
