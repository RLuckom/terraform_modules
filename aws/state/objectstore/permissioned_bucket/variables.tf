variable "bucket" {
  type = string
}

variable versioning {
  type = list(object({
    enabled = bool
  }))
  default = []
}

variable "website_configs" {
  type = list(object({
    index_document = string
    error_document = string
  }))
  default = []
}

variable "acl" {
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

variable "lambda_notifications" {
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

variable "object_policy_statements" {
  type = list(object({
    actions = list(string)
    principals = list(object({
      type = string
      identifiers = list(string)
    }))
  }))
  default = []
}

variable "bucket_policy_statements" {
  type = list(object({
    actions = list(string)
    principals = list(object({
      type = string
      identifiers = list(string)
    }))
  }))
  default = []
}

locals {
  need_policy = length(concat(var.bucket_policy_statements, var.object_policy_statements, var.lambda_notifications)) > 0
}
