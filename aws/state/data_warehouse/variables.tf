variable scope {
  type = string
}

variable data_bucket {
  type = string
}

variable database_name {
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
    partition_keys = list(object({
      name = string
      type = string
    }))
  }))
  default = {}
}

variable table_permission_names {
  type = map(object({
    add_partition_permission_names = list(string)
    query_permission_names = list(string)
  }))
  default = {}
}

resource aws_glue_catalog_database database {
  name = var.database_name
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
  partition_keys = each.value.partition_keys
}
data "aws_caller_identity" "current" {}

locals {
  default_catalog = "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:catalog"
  default_db = "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:database/default"
}

module glue_table_add_partition_permissions {
  source = "github.com/RLuckom/terraform_modules//aws/iam/add_policy_to_roles"
  for_each = var.table_configs
  policy_name = "${each.key}-addpart"
  role_names = lookup(var.table_permission_names, each.key, {
    add_partition_permission_names = [] 
    query_permission_names = [] 
  }).add_partition_permission_names
  policy_statements = [
    {
      actions   =  [
        "athena:StartQueryExecution",
        "athena:GetQueryResults",
        "athena:GetQueryExecution"
      ]
      resources = [
        "arn:aws:athena:*"
      ]
    },
    {
      actions   =  [
        "glue:GetDatabase",
        "glue:GetTable"
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
        local.default_catalog,
        module.table[each.key].table.arn,
        "${module.table[each.key].table.arn}/*",
      ]
    },
  ]
}

module glue_table_query_permissions {
  source = "github.com/RLuckom/terraform_modules//aws/iam/add_policy_to_roles"
  for_each = var.table_configs
  policy_name = "${each.key}-query"
  role_names = lookup(var.table_permission_names, each.key, {
    query_permission_names = [] 
    add_partition_permission_names = [] 
  }).query_permission_names
  policy_statements = [
    {
      actions   =  [
        "athena:StartQueryExecution",
        "athena:GetQueryResults",
        "athena:GetQueryExecution"
      ]
      resources = [
        "arn:aws:athena:*"
      ]
    },
    {
      actions   =  [
        "glue:GetDatabase",
        "glue:GetPartitions",
        "glue:GetTable"
      ]
      resources = [
        local.default_db,
        local.default_catalog,
        aws_glue_catalog_database.database.arn,
        module.table[each.key].table.arn,
        "${module.table[each.key].table.arn}/*",
      ]
    },
  ]
}
