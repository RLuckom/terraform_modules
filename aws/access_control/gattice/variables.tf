variable security_scope {
  type = string
}

variable token_issuer {
  type = string
}

variable client_id {
  type = string
}

variable client_secret {
  type = string
}

variable nonce_signing_secret {
  type = string
}

variable auth_domain {
  type = string
}

variable user_group_name {
  type = string
}

variable aws_credentials_file {
  type = string
  default = "/.aws/credentials"
}

variable log_source {
  type = string
  default = ""
}

variable log_source_instance {
  type = string
  default = ""
}

//TODO set each config separately, make the fn names the component?
variable component {
  type = string
  default = ""
}

variable log_level {
  type = string
  default = "ERROR"
}

variable http_header_values {
  type = map(string)
  default = null
}
