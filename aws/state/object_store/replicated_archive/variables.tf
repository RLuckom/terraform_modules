terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
      configuration_aliases = [ aws.replica1, aws.replica2, aws.replica3]
    }
  }
}

variable region1 {
  type = string
  default = "eu-central-1"
}

variable region2 {
  type = string
  default = "ap-southeast-2"
}

variable region3 {
  type = string
  default = "ca-central-1"
}

variable need_policy_override {
  type = bool
  default = true
}

variable really_allow_delete {
  type = bool
  default = false
}

variable account_id {
  type = string
}

variable region {
  type = string
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
    filter_tags = map(string)
    completion_tags = list(object({
      Key = string
      Value = string
    }))
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
    metric_table = string
  })
  default = {
    bucket = ""
    prefix = ""
    metric_table = ""
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
      tags = source.filter_tags
    }
    completion_tags = source.completion_tags
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
  account_id = var.account_id
  region = var.region
  replication_time_limit = 15
  replication_memory_size = 256
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
  force_destroy = var.really_allow_delete
  account_id = var.account_id
  region = var.region1
  need_policy_override = var.need_policy_override
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
  force_destroy = var.really_allow_delete
  account_id = var.account_id
  region = var.region2
  need_policy_override = var.need_policy_override
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
  force_destroy = var.really_allow_delete
  account_id = var.account_id
  region = var.region3
  need_policy_override = var.need_policy_override
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
