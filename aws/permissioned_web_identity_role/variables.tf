variable role_name {
  type = string
}

variable account_id {
  type = string
}

variable identity_pool_id {
  type = string
}

variable "role_policy" {
  type = list(object({
    actions = list(string)
    resources = list(string)
  }))
  default = []
}

variable "require_authenticated" {
  type = bool
  default = true
}
