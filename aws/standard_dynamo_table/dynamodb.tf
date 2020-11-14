resource "aws_dynamodb_table" "standard_table" {
  name             = var.table_name
  hash_key         = var.partition_key.name
  billing_mode     = "PAY_PER_REQUEST"
  stream_enabled   = false
  range_key      = var.range_key.name == "" ? length(var.ttl) > 0 ? var.ttl[0].attribute_name : "" : var.range_key.name

  dynamic "ttl" {
    for_each = var.ttl
    content {
      enabled = ttl.value.enabled
      attribute_name = ttl.value.attribute_name
    }
  }

  dynamic "attribute" {
    for_each = concat([var.partition_key], var.range_key.name != "" ? [var.range_key] : [], var.additional_keys)

    content {
      name               = attribute.value.name
      type               = attribute.value.type
    }
  }

  dynamic "attribute" {
    for_each = var.ttl

    content {
      name               = attribute.value.attribute_name
      type               = "N" // ttl key must be number
    }
  }

  dynamic "replica" {
    for_each = var.replica_regions

    content {
      region_name               = replica
    }
  }
}
