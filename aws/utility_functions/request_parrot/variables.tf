variable account_id {
  type = string
}

variable region {
  type = string
}

variable unique_suffix {
  type = string
  default = ""
}

variable security_scope {
  type = string
  default = ""
}

variable action_name {
  type = string
  default = "request-parrot"
}

variable function_time_limit {
  type = number
  default = 10
}

variable function_memory_size {
  type = number
  default = 128
}
