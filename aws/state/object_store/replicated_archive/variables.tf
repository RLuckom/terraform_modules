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
  name = "${var.bucket_prefix}-replica1"
  versioning = [{
    enabled = true
  }]
  providers = {
    aws = aws.replica1
  }
}

module replica_bucket_2 {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/bucket"
  name = "${var.bucket_prefix}-replica2"
  versioning = [{
    enabled = true
  }]
  providers = {
    aws = aws.replica2
  }
}

module replica_bucket_3 {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/bucket"
  name = "${var.bucket_prefix}-replica3"
  versioning = [{
    enabled = true
  }]
  providers = {
    aws = aws.replica3
  }
}
