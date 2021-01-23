variable name {
  type = string
}

variable prefix_athena_query_permissions {
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
    id = string
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

locals {
  need_policy = length(concat(
    var.principal_bucket_permissions,
    var.principal_prefix_object_permissions,
    var.bucket_permissions,
    var.prefix_object_permissions,
    var.lambda_notifications,
    var.prefix_athena_query_permissions
  )) > 0
}
