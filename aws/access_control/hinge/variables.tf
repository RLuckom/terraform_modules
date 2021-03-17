variable system_id {
  type = object({
    security_scope = string
    subsystem_name = string
  })
}

locals {
  name = "${var.system_id.security_scope}-${var.system_id.subsystem_name}"
}

variable client_id {
  type = string
}

variable provider_endpoint {
  type = string
}

variable allow_unauthenticated_identities {
  type = bool
  default = false
}

variable server_side_token_check {
  type = bool
  default = true
}

variable authenticated_policy_statements {
  type = list(object({
    actions = list(string)
    resources = list(string)
  }))
  default = []
}
