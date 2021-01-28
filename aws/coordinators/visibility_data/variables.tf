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

locals {
  scopes = var.scopes
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
        },
      ),
      zipmap(
      [ for k, v in var.serverless_site_configs : replace("${trimsuffix(v.controlled_domain_part, ".")}.${trimprefix(v.top_level_domain, ".")}", ".", "_") if v.scope == scope],
      [ for k, v in var.serverless_site_configs : v if v.scope == scope],
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
        }]
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

output visibility_lifecycle_rules {
  value = concat(
    local.cloudfront_log_path_lifecycle_rules,
    local.lambda_log_path_lifecycle_rules,
    local.athena_result_path_lifecycle_rules
  )
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
