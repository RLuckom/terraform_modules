variable name {
  type = string
}

variable website_access_principal {
  type = object({
    type = string
    identifiers = list(string)
  })
  default = {
    type = "*"
    identifiers = ["*"]
  }
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

variable additional_allowed_origins {
  type = list(string)
  default = []
}

variable domain_parts {
  type = object({
    top_level_domain = string
    controlled_domain_part = string
  })
}
