variable table_name {
  type = string
}

variable region {
  type = string
}

variable account_id {
  type = string
}

variable unique_suffix {
  type = string
  default = ""
}

variable delete_item_permission_role_names {
  type = list(string)
  default = []
}

variable read_permission_role_names {
  type = list(string)
  default = []
}

variable write_permission_role_names {
  type = list(string)
  default = []
}

variable put_item_permission_role_names {
  type = list(string)
  default = []
}

// stream items table vars

variable "ttl" {
  type = list(object({
    enabled = bool
    attribute_name = string
  }))
  default = []
}

variable "partition_key" {
  type = object({
    name = string
    type = string 
  })
}

variable "range_key" {
  type = object({
    name = string
    type = string 
  })
  default = {
    name = ""
    type = "N"
  }
}

variable "global_indexes" {
  type = list(
    object({
      name = string
      hash_key = string
      range_key = string
      write_capacity = number
      read_capacity = number
      projection_type = string
      non_key_attributes = list(string)
    })
  )
  default = []
}

variable "additional_keys" {
  type = list(object({
    name = string
    type = string 
  }))
  default = []
}

variable "replica_regions" {
  type = list(string)
  default = []
}

locals {
  table_name = var.unique_suffix == "" ? var.table_name : "${var.table_name}-${var.unique_suffix}"
}
