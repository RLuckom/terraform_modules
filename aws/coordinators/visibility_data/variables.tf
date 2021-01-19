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

locals {
  cloudfront_prefix = trim(var.cloudfront_prefix, "/")
  athena_prefix = trim(var.cloudfront_prefix, "/")
  lambda_prefix = trim(var.cloudfront_prefix, "/")
}

variable cloudfront_distributions {
  type = map(object({
    domain_parts = {
      top_level_domain = string
      controlled_domain_part = string
    }
    purpose_descriptor = string
    log_cookies = bool
  }))
  default = {}
}

variable athena_table_spaces {
  type = map(object({
    scope = string
    database = string
    table = string
  }))
  default = {}
}

data aws_caller_identity current {}

variable lambdas {
  type = map(object({
    scope = string
    name = string
    debug = bool
    region = string
  }))
  default = {}
}

locals {
  cloudfront_distributions = zipmap(
    [ for k in keys(var.cloudfront_distributions) : k ]
    [ for v in values(var.cloudfront_distributions) : {
      domain = "${trimend(v.domain_parts.controlled_domain_part, ".")}.${trimstart(v.domain_parts.top_level_domain)}"
      log_prefix = "${local.cloudfront_prefix}/domain=${trimend(v.domain_parts.controlled_domain_part, ".")}.${trimstart(v.domain_parts.top_level_domain)}/"
      log_delivery_bucket = local.log_delivery_bucket
      log_cookies = v.log_cookies
      domain_parts = v.domain_parts
    }]
  )
  athena_table_spaces = zipmap(
    [ for k in keys(var.athena_table_spaces) : k ]
    [ for v in values(var.athena_table_spaces) : {
      log_prefix = "${local.athena_prefix}/scope=${v.scope}/database=${v.database}/table=${v.table}/"
      scope = v.scope
      database = v.database
      table = v.table
      athena_results_bucket = local.athena_results_bucket
    }]
  )
  lambdas = zipmap(
    [ for k in keys(var.lambdas) : k ]
    [ for v in values(var.lambdas) : {
      log_prefix = "${local.lambda_prefix}/scope=${v.scope}/"
      log_bucket = local.visibility_data_bucket
      scope = v.scope
      name = "${v.action}${v.scope == "" ? "" : "-"}${var.scope}"
      action = v.action
      debug = v.debug
      arn = "arn:aws:lambda:${v.region}:${aws_caller_identity.current.account_id}:function:${v.action}${v.scope == "" ? "" : "-"}${var.scope}"
    }]
  )
}

output visibility_data_bucket {
  value = local.visibility_data_bucket
}

output athena_results_bucket {
  value = athena_results_bucket
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

output lambdas {
  value = local.lambdas
}
