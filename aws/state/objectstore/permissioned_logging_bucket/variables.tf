variable move_objects_out_permissions {
  type = list(object({
    prefix = string
    arns = list(string)
  }))
  default = []
}

variable bucket_name {
  type = string
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
