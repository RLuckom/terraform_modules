variable "account_id" {
  type = string
}

variable "role_name" {
  type = string
}

variable "principals" {
  type = list(object({
    type = string
    identifiers = list(string)
  }))
  default = []
}

variable "role_policy" {
  type = list(object({
    actions = list(string)
    resources = list(string)
  }))
  default = []
}

variable unique_suffix {
  type = string
  default = ""
}

locals {
  role_name = var.unique_suffix != "" ? "${var.role_name}-${var.unique_suffix}" : var.role_name
}
