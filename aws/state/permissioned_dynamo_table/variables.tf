variable "table_name" {
  type = string
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
  default = {
    name = "id"
    type = "S"
  }
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
