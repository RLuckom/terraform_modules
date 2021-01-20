variable scope {
  type = string
}

variable data_bucket {
  type = string
}

variable table_configs {
  type = map(object({
    bucket_prefix = string
    skip_header_line_count = number
    ser_de_info = object({
      name = string
      serialization_library = string
      parameters = map(string)
    })
    columns = list(object({
      name = string
      type = string
    }))
    add_partition_permission_arns = list(string)
  }))
  default = {}
}

resource aws_glue_catalog_database database {
  name = "${var.scope}-${var.data_bucket}"
}

module table {
  source = "github.com/RLuckom/terraform_modules//aws/state/permissioned_glue_table"
  for_each = var.table_configs
  table_name          = each.key
  external_storage_bucket_id = var.data_bucket
  partition_prefix = each.value.bucket_prefix
  db = {
    name = aws_glue_catalog_database.database.name
    arn = aws_glue_catalog_database.database.arn
  }
  skip_header_line_count = each.value.skip_header_line_count
  ser_de_info = each.value.ser_de_info 
  columns = each.value.columns
}
data "aws_caller_identity" "current" {}

locals {
  default_catalog = "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:catalog"
  default_db = "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:database/default"
}

module glue_table_add_partition_permissions {
  source = "github.com/RLuckom/terraform_modules//aws/iam/add_policy_to_roles?ref=tape-deck-storage"
  for_each = var.table_configs
  policy_name = "${each.key}-addpart"
  role_arns = each.value.add_partition_permission_arns
  policy_statements = [
    {
      actions   =  [
        "glue:GetDatabase",
      ]
      resources = [
        local.default_db,
        local.default_catalog,
        aws_glue_catalog_database.database.arn,
      ]
    },
    {
      actions   =  [
        "glue:CreatePartition",
        "glue:GetTable",
        "glue:BatchCreatePartition"
      ]
      resources = [
        aws_glue_catalog_database.database.arn,
        module.table[each.key].table.arn,
        "${module.table[each.key].table.arn}/*",
      ]
    },
  ]
}
