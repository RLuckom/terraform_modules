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

variable required_group {
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

variable plugin_configs {
  type = map(object({
    role_name_stem = string
    policy_statements = list(object({
      actions = list(string)
      resources = list(string)
    }))
  }))
  default = {}
}

locals {
  plugin_role_map = zipmap(
    keys(var.plugin_configs),
    [for k, v in var.plugin_configs : module.authenticated_role[k].role.arn]
  )
}
