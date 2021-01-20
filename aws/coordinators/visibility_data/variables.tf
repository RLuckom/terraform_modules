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

variable cloudfront_distributions {
  type = map(object({
    top_level_domain = string
    controlled_domain_part = string
  }))
  default = {}
}

locals {
  cloudfront_delivery_bucket = var.cloudfront_delivery_bucket
  visibility_data_bucket = var.visibility_data_bucket
  athena_results_bucket = var.athena_results_bucket == "" ? var.visibility_data_bucket : var.athena_results_bucket
}

variable athena_prefix {
  type = string
  default = "athena"
}

variable cloudfront_prefix {
  type = string
  default = "cloudfront-logs"
}

variable lambda_prefix {
  type = string
  default = "lambda-logs"
}

data aws_caller_identity current {}

locals {
  cloudfront_prefix = trim(var.cloudfront_prefix, "/")
  athena_prefix = trim(var.cloudfront_prefix, "/")
  lambda_prefix = trim(var.cloudfront_prefix, "/")
}

locals {
  cloudfront_distributions = zipmap(
    [ for k in keys(var.cloudfront_distributions) : k ],
    [ for k, v in var.cloudfront_distributions : {
      domain = "${trimsuffix(v.controlled_domain_part, ".")}.${trimprefix(v.top_level_domain, ".")}"
      cloudfront_log_prefix = "${local.cloudfront_prefix}/domain=${trimsuffix(v.controlled_domain_part, ".")}.${trimprefix(v.top_level_domain, ".")}/"
      lambda_log_prefix = "${local.lambda_prefix}/scope=${k}/"
      lambda_source_bucket = var.lambda_source_bucket
      log_delivery_bucket = local.cloudfront_delivery_bucket
      log_partition_bucket = local.visibility_data_bucket
      domain_parts = v
      scope = k
    }]
  )
  cloudfront_log_archive_routes = [ for k, v in var.cloudfront_distributions : {
    delivery_prefix = "${local.cloudfront_prefix}/domain=${trimsuffix(v.controlled_domain_part, ".")}.${trimprefix(v.top_level_domain, ".")}/"
    archive_prefix = "${local.cloudfront_prefix}/domain=${trimsuffix(v.controlled_domain_part, ".")}.${trimprefix(v.top_level_domain, ".")}/"
    delivery_bucket = local.cloudfront_delivery_bucket
    archive_bucket = local.visibility_data_bucket
  }]
  athena_table_spaces = zipmap(
    [ for scope in var.scopes : scope ],
    [ for scope in var.scopes : {
      cloudfront_result_prefix = "${local.athena_prefix}/${local.cloudfront_prefix}/"
      lambda_result_prefix = "${local.athena_prefix}/${local.lambda_prefix}/"
      scope = scope
      athena_results_bucket = local.athena_results_bucket
    }]
  )
  lambda_log_configs = zipmap(
    [ for scope in var.scopes : scope ],
    [ for scope in var.scopes : {
      log_prefix = "${local.lambda_prefix}/scope=${scope}/"
      log_bucket = local.visibility_data_bucket
      source_bucket = var.lambda_source_bucket
      scope = scope
    }]
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

output cloudfront_distributions {
  value = local.cloudfront_distributions
}

output athena_table_spaces {
  value = local.athena_table_spaces
}

output lambda_source_bucket {
  value = var.lambda_source_bucket
}

output lambda_log_configs {
  value = local.lambda_log_configs
}
