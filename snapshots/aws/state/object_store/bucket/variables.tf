terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
  }
}

variable name {
  type = string
}

variable unique_suffix {
  type = string
  default = ""
}

variable need_policy_override {
  type = bool
  default = false
}

variable enable_acls {
  type = bool
  default = false
}

variable security_scope {
  type = string
  default = ""
}

variable force_destroy {
  type = bool
  default = false
}

variable account_id {
  type = string
}

variable region {
  type = string
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

variable prefix_list_permissions {
  type = list(object({
    prefix = string
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

variable prefix_object_denials {
  type = list(object({
    permission_type = string
    prefix = string
    arns = list(string)
  }))
  default = []
}

variable suffix_object_denials {
  type = list(object({
    permission_type = string
    suffix = string
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

variable principal_prefix_object_denials {
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

variable principal_suffix_object_denials {
  type = list(object({
    permission_type = string
    suffix = string
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
  default = ""
}

variable grant_based_acl {
  type = list(object({
    owner_full_control = bool
    id_grants = list(object({
      grantee_id = string
      grantee_type = string
      permission = string
    }))
    group_grants = list(object({
      grantee_uri = string
      permission = string
    }))
  }))
  default = []
}

variable request_payer {
  type = string
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

variable utility_function_logging_config {
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

variable utility_function_event_configs {
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

locals {
  bucket_name = var.unique_suffix == "" ? var.name : "${var.name}-${var.unique_suffix}"
  lambda_notifications = var.lambda_notifications
  effective_notifications = module.splitter_lambda.manual_notifications ? module.splitter_lambda.bucket_notifications : local.lambda_notifications
  lambda_invoke_permissions_needed = distinct([for notif in local.effective_notifications : notif.lambda_name])
}
