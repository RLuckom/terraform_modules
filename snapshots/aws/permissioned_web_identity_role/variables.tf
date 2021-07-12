variable role_name {
  type = string
}

variable account_id {
  type = string
}

variable identity_pool_id {
  type = string
}

variable unique_suffix {
  type = string
  default = ""
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

locals {
  role_name = var.unique_suffix != "" ? "${var.role_name}-${var.unique_suffix}" : var.role_name
}
