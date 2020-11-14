variable "table_name" {
  type = string
}

variable "external_storage_bucket_id" {
  type = string
  default = ""
}

variable "external_storage_bucket_arn" {
  type = string
  default = ""
}

variable "db" {
  type = object({
    name = string
    arn = string
  })
}

variable "metadata_bucket_name" {
  type = string
  default = ""
}

variable "metadata_bucket_arn" {
  type = string
  default = ""
}

variable "stored_as_sub_directories" {
  default = false
}

variable "compressed" {
  type = bool
  default = true
}

variable "skip_header_line_count" {
  type = number
  default = 0
}

variable "ser_de_info" {
  type = object({
    name = string
    serialization_library = string
    parameters = map(string)
  })
}

variable "columns" {
  type = list(object({
    name = string
    type = string
  }))
}

variable "partition_keys" {
  type = list(object({
    name = string
    type = string
  }))
  default = [

  {
    name = "year"
    type = "string"
  },

  {
    name = "month"
    type = "string"
  },

  {
    name = "day"
    type = "string"
  },

  {
    name = "hour"
    type = "string"
  }
  ]
}

variable "partition_prefix" {
  type = string
  default = ""
}
