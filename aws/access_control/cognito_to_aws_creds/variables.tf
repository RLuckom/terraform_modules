variable identity_pool_id {
  type = string
}

variable user_pool_endpoint {
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

variable api_path {
  type = string
  default = ""
}

variable gateway_name_stem {
  type = string
  default = ""
}

variable authorizer_name {
  type = string
  default = "default"
}

variable id_token_name {
  type = string
  default = "ID-TOKEN"
}
