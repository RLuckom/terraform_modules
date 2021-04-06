variable action_name {
  type = string
  default = "replication"
}

variable default_destination_bucket_name {
  type = string
  default = ""
}

variable default_source_bucket_name {
  type = string
  default = ""
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

variable replication_time_limit {
  type = number
  default = 10
}

variable replication_memory_size {
  type = number
  default = 128
}

variable security_scope {
  type = string
  default = ""
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

variable replication_configuration {
  type = object({
    role_arn = string
    donut_days_layer = object({
      present = string
      arn = string
    })
    rules = list(object({
      priority = number
      source_bucket = string
      filter = object({
        prefix = string
        suffix = string
        tags = map(string)
      })
      enabled = bool
      replicate_delete = bool
      destination = object({
        bucket = string
        prefix = string
        storage_class = string
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

locals {
  distinct_sources = distinct([for rule in var.replication_configuration.rules : {
    bucket = rule.source_bucket == "" ? var.default_source_bucket_name : rule.source_bucket
    prefix = rule.filter.prefix
    suffix = rule.filter.suffix
    tags = rule.filter.tags
    replicate_delete = rule.replicate_delete
  }])
  distinct_destinations = distinct([for rule in var.replication_configuration.rules : {
    bucket = rule.destination.bucket == "" ? var.default_destination_bucket_name : rule.destination.bucket
    prefix = rule.destination.prefix
    replicate_delete = rule.replicate_delete
  }])
  source_buckets = distinct(
    [for rule in var.replication_configuration.rules : rule.source_bucket]
  )
  destination_buckets = distinct(
    [for rule in var.replication_configuration.rules : rule.destination.bucket == "" ? var.default_destination_bucket_name : rule.destination.bucket]
  )
  need_donut_days_layer = length(var.replication_configuration.rules) > 0 && var.replication_configuration.donut_days_layer.present == false
  need_replication_lambda = length(var.replication_configuration.rules) > 0
  lambda_notifications = zipmap(
    local.source_buckets,
    [for bucket in local.source_buckets : [for source in local.distinct_sources : {
    lambda_arn = module.replication_lambda[0].lambda.arn
    lambda_name = module.replication_lambda[0].lambda.function_name
    lambda_role_arn = module.replication_lambda[0].role.arn
    permission_type = "read_known_objects"
    events = source.replicate_delete ? ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"] : ["s3:ObjectCreated:*"]
    filter_prefix = source.prefix == "" ? null : source.prefix
    filter_suffix = source.suffix == "" ? null : source.suffix
  } if source.bucket == bucket]])
  replication_function_prefix_write_permissions = zipmap(
    local.destination_buckets,
    [for bucket in local.destination_buckets : [ for dest in local.distinct_destinations : {
      prefix = dest.prefix
      permission_type = "put_object"
      arns = [module.replication_lambda[0].role.arn]
    } if dest.bucket == bucket
  ]])
  replication_function_prefix_delete_permissions = zipmap(
    local.destination_buckets,
    [for bucket in local.destination_buckets : [ for dest in local.distinct_destinations : {
      prefix = dest.prefix
      permission_type = "delete_object"
      arns = [module.replication_lambda[0].role.arn]
    } if dest.replicate_delete && dest.bucket == bucket
  ]])
    all_buckets = distinct(concat(local.source_buckets, local.destination_buckets))
  replication_function_prefix_permissions = zipmap(
    local.all_buckets,
    [ for bucket in local.all_buckets : concat(
      contains(keys(local.replication_function_prefix_delete_permissions), bucket) ? local.replication_function_prefix_delete_permissions[bucket] : [],
      contains(keys(local.replication_function_prefix_write_permissions), bucket) ? local.replication_function_prefix_write_permissions[bucket] : [],
    )])
}
