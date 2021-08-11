resource "aws_dynamodb_table" "standard_table" {
  name             = local.table_name
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

  dynamic "global_secondary_index" {
    for_each = var.global_indexes
    content {
      name               = global_secondary_index.value.name
      hash_key           = global_secondary_index.value.hash_key
      range_key          = global_secondary_index.value.range_key
      write_capacity     = global_secondary_index.value.write_capacity
      read_capacity      = global_secondary_index.value.read_capacity
      projection_type    = global_secondary_index.value.projection_type
      non_key_attributes = global_secondary_index.value.non_key_attributes
    }
  }

  dynamic "replica" {
    for_each = var.replica_regions

    content {
      region_name               = replica
    }
  }
}

locals {
  table_and_index_arns = concat([aws_dynamodb_table.standard_table.arn], [ for v in var.global_indexes : "${aws_dynamodb_table.standard_table.arn}/index/${v.name}"])
}

module dynamo_table_delete_item_permissions {
  source = "../../iam/add_policy_to_roles"
  policy_name = "${aws_dynamodb_table.standard_table.name}-delete"
  role_names = var.delete_item_permission_role_names
  policy_statements = [
    {
      actions   = ["dynamodb:DeleteItem"]
      resources = local.table_and_index_arns
    }
  ]
}

module dynamo_table_read_permissions {
  source = "../../iam/add_policy_to_roles"
  policy_name = "${aws_dynamodb_table.standard_table.name}-read"
  role_names = var.read_permission_role_names
  policy_statements = [
    {
      actions   = [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchGetItem",
        "dynamodb:PartiQLSelect",
      ]
      resources = local.table_and_index_arns
    }
  ]
}

module dynamo_table_write_permissions {
  source = "../../iam/add_policy_to_roles"
  policy_name = "${aws_dynamodb_table.standard_table.name}-write"
  role_names = var.write_permission_role_names
  policy_statements = [
    {
      actions   = [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:PartiQLDelete",
        "dynamodb:PartiQLInsert",
        "dynamodb:PartiQLUpdate",
      ]
      resources = local.table_and_index_arns
    }
  ]
}

module dynamo_table_put_item_permissions {
  source = "../../iam/add_policy_to_roles"
  policy_name = "${aws_dynamodb_table.standard_table.name}-put"
  role_names = var.put_item_permission_role_names
  policy_statements = [
    {
      actions   = ["dynamodb:PutItem"]
      resources = local.table_and_index_arns
    }
  ]
}
