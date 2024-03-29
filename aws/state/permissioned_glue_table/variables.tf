variable "table_name" {
  type = string
}

variable "external_storage_bucket_id" {
  type = string
}

variable "db" {
  type = object({
    name = string
    arn = string
  })
}

variable unique_suffix {
  type = string
  default = ""
}

variable "stored_as_sub_directories" {
  type = bool
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

locals {
  table_name = var.unique_suffix == "" ? var.table_name : "${var.table_name}_${var.unique_suffix}"
}
