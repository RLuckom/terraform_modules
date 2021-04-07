provider "aws" {
  alias = "replica1"
}

provider "aws" {
  alias = "replica2"
}

provider "aws" {
  alias = "replica3"
}

variable bucket_prefix {
  type = string
}

variable security_scope {
  type = string
  default = ""
}

variable replication_sources {
  type = list(object({
    bucket = string
    prefix = string
    suffix = string
    tags = map(string)
    storage_class = string
  }))
  default = []
}

variable donut_days_layer_config {
  type = object({
    present = bool
    arn = string
  })
  default = {
    present = false
    arn = ""
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
  buckets = [
    "${var.bucket_prefix}-replica1",
    "${var.bucket_prefix}-replica2",
    "${var.bucket_prefix}-replica3",
  ]
  rules = flatten([for source in var.replication_sources : [for bucket in local.buckets : {
    priority = 0 # lambda replication doesn't care
    source_bucket = source.bucket
    filter = {
      prefix = source.prefix
      suffix = source.suffix
      tags = source.tags
    }
    enabled = true
    replicate_delete = false
    destination = {
      bucket = bucket
      prefix = "${source.bucket}/${source.prefix}"
      storage_class = source.storage_class
      manual = true
    }
  }]])
}

module replication_lambda {
  source = "github.com/RLuckom/terraform_modules//aws/utility_functions/replicator"
  logging_config = var.replication_function_logging_config
  lambda_event_configs = var.replication_lambda_event_configs
  security_scope = var.security_scope
  replication_configuration = {
    role_arn = ""
    donut_days_layer = var.donut_days_layer_config
    rules = local.rules
  }
}

module replica_bucket_1 {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/bucket"
  name = local.buckets[0]
  versioning = [{
    enabled = true
  }]
  prefix_object_permissions = module.replication_lambda.replication_function_permissions_needed[local.buckets[0]]
  providers = {
    aws = aws.replica1
  }
}

module replica_bucket_2 {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/bucket"
  name = local.buckets[1]
  versioning = [{
    enabled = true
  }]
  prefix_object_permissions = module.replication_lambda.replication_function_permissions_needed[local.buckets[1]]
  providers = {
    aws = aws.replica2
  }
}

module replica_bucket_3 {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/bucket"
  name = local.buckets[2]
  prefix_object_permissions = module.replication_lambda.replication_function_permissions_needed[local.buckets[2]]
  versioning = [{
    enabled = true
  }]
  providers = {
    aws = aws.replica3
  }
}

output replication_lambda {
  value = module.replication_lambda.replication_lambda
}

output replication_function_permissions_needed {
  value = module.replication_lambda.replication_function_permissions_needed
}

output bucket_notifications {
  value = module.replication_lambda.bucket_notifications
}

output lambda_logging_roles {
  value = module.replication_lambda.lambda_logging_roles
}
