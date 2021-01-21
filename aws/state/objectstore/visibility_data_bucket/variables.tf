variable prefix_put_permissions {
  type = list(object({
    prefix = string
    arns = list(string)
  }))
  default = []
}

variable prefix_athena_query_permissions {
  type = list(object({
    prefix = string
    arns = list(string)
  }))
  default = []
}

variable list_bucket_permission_arns {
  type = list(string)
  default = []
}

variable bucket_name {
  type = string
}

variable partitioned_data_sink {
  type = list(object({
    filter_prefix = string
    filter_suffix = string
    lambda_arn = string
    lambda_name = string
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

variable object_policy_statements {
  type = list(object({
    actions = list(string)
    prefix = string
    principals = list(object({
      type = string
      identifiers = list(string)
    }))
  }))
  default = []
}

variable bucket_policy_statements {
  type = list(object({
    actions = list(string)
    principals = list(object({
      type = string
      identifiers = list(string)
    }))
  }))
  default = []
}
