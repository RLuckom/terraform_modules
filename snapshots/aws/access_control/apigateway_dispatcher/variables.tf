variable identity_pool_id {
  type = string
}

variable account_id {
  type = string
}

variable region {
  type = string
}

variable user_pool_endpoint {
  type = string
}

variable client_id {
  type = string
}

variable aws_sdk_layer {
  type = object({
    present = bool
    arn = string
  })
  default = {
    present = false
    arn = ""
  }
}

variable plugin_api_root {
  type = string
  default = "/api/plugins/"
}

variable plugin_role_map {
  type = map(string)
  default = {}
}

variable route_to_function_name_map {
  type = map(string)
  default = {}
}

variable id_token_name {
  type = string
  default = "ID-TOKEN"
}
