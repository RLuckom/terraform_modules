variable name {
  type = string
}

variable security_scope {
  type = string
  default = ""
}

variable force_destroy {
  type = bool
  default = false
}

variable bucket_logging_config {
  type = object({
    target_bucket = string
    target_prefix = string
  })
  default = {
    target_bucket = ""
    target_prefix = ""
  }
}

variable prefix_athena_query_permissions {
  type = list(object({
    log_storage_prefix = string
    result_prefix = string
    arns = list(string)
  }))
  default = []
}

variable lambda_notifications {
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

variable lifecycle_rules {
  type = list(object({
    prefix = string
    tags = map(string)
    enabled = bool
    expiration_days = number
  }))
  default = []
}

variable prefix_object_permissions {
  type = list(object({
    permission_type = string
    prefix = string
    arns = list(string)
  }))
  default = []
}

variable bucket_permissions {
  type = list(object({
    permission_type = string
    arns = list(string)
  }))
  default = []
}

variable principal_prefix_object_permissions {
  type = list(object({
    permission_type = string
    prefix = string
    principals = list(object({
      type = string
      identifiers = list(string)
    }))
  }))
  default = []
}

variable principal_bucket_permissions {
  type = list(object({
    permission_type = string
    principals = list(object({
      type = string
      identifiers = list(string)
    }))
  }))
  default = []
}

variable versioning {
  type = list(object({
    enabled = bool
  }))
  default = []
}

variable website_configs {
  type = list(object({
    index_document = string
    error_document = string
  }))
  default = []
}

variable acl {
  type = string
  default = "private"
}

variable request_payer {
  default = "BucketOwner"
}

variable cors_rules {
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers = list(string)
    max_age_seconds = number
  }))
  default = []
}

variable replication_configuration {
  type = object({
    role_arn = string
    donut_days_layer = object({
      present = string
      arn = string
    })
    rules = list(object({
      priority = number
      filter = object({
        prefix = string
        suffix = string
        tags = map(string)
      })
      enabled = bool
      destination = object({
        bucket = string
        prefix = string
        manual = bool
      })
    }))
  })
  default = {
    role_arn = ""
    donut_days_layer = {
      present = false
      arn = ""
    }
    rules = []
  }
}

variable replication_lambda_event_configs {
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

variable replication_function_logging_config {
  type = object({
    bucket = string
    prefix = string
  })
  default = {
    bucket = ""
    prefix = ""
  }
}

locals {
  auto_replication_rules = [for rule in var.replication_configuration.rules : rule if (rule.destination.prefix == "" && !rule.destination.manual && rule.filter.suffix == "")]
  manual_replication_rules = [for rule in var.replication_configuration.rules : rule if (rule.enabled && (rule.destination.prefix != "" || rule.destination.manual || rule.filter.suffix != ""))]
  // we only need to create a role if there are autoreplication rules, because we automatically
  // assign a role to the lambda we create already. So if the lambda gets created so will a role.
  need_replication_role = var.replication_configuration.role_arn == "" && length(local.auto_replication_rules) > 0
  need_donut_days_layer = length(local.manual_replication_rules) > 0 && var.replication_configuration.donut_days_layer.present == false
  need_replication_lambda = length(local.manual_replication_rules) > 0
  lambda_notifications = concat(var.lambda_notifications, [for rule in local.manual_replication_rules : {
    lambda_arn = module.replication_lambda[0].lambda.arn
    lambda_name = module.replication_lambda[0].lambda.function_name
    events = ["s3:ObjectCreated:*"]
    filter_prefix = rule.filter.prefix == "" ? null : rule.filter.prefix
    filter_suffix = rule.filter.suffix == "" ? null : rule.filter.suffix
  }])
  replication_function_prefix_read_permissions = [ for rule in local.manual_replication_rules : {
      prefix = rule.filter.prefix
      permission_type = "read_known_objects"
      arns = [module.replication_lambda[0].role.arn]
    }
  ]
  replication_function_prefix_write_permissions = [ for rule in local.manual_replication_rules : {
      prefix = rule.destination.prefix
      permission_type = "put_object"
      arns = [module.replication_lambda[0].role.arn]
    } if rule.destination.bucket == var.name
  ]
  replication_function_prefix_permissions = concat(local.replication_function_prefix_read_permissions, local.replication_function_prefix_write_permissions)
  replication_function_external_buckets = [for rule in local.manual_replication_rules: rule.destination.bucket if rule.destination.bucket != var.name]
  replication_function_permissions_needed = zipmap(
    local.replication_function_external_buckets,
    [for bucket in local.replication_function_external_buckets: concat([ for rule in local.manual_replication_rules : {
      prefix = rule.destination.prefix 
      permission_type = "put_object"
      arns = [module.replication_lambda[0].role.arn]
    } if rule.destination.bucket == bucket], var.replication_function_logging_config.bucket == bucket ? [{
      prefix = var.replication_function_logging_config.prefix 
      permission_type = "put_object"
      arns = [module.replication_lambda[0].role.arn]
    }] : [])
  ])
}
