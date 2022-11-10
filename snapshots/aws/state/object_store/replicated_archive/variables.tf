terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
      configuration_aliases = [ aws.replica1, aws.replica2, aws.replica3]
    }
  }
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

variable unique_suffix {
  type = string
  default = ""
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
