variable "bucket_name" {
  type = string
  default = ""
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
    prefix = string
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
