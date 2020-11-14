variable "role_policy" {
  type = list(object({
    actions = list(string)
    resources = list(string)
  }))
  default = []
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
