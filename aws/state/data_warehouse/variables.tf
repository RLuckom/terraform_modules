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
  roles_with_add_partition_permissions = distinct(flatten(values(var.table_permission_names).*.add_partition_permission_names))
  per_role_add_partition_policy_map = zipmap(
    local.roles_with_add_partition_permissions,
    [for role_name in local.roles_with_add_partition_permissions : flatten([for table_name, config in var.table_configs: [
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
        module.table[table_name].table.arn,
        "${module.table[table_name].table.arn}/*",
      ]
    },
  ] if contains(lookup(var.table_permission_names, table_name, {
    add_partition_permission_names = [] 
    query_permission_names = [] 
  }).add_partition_permission_names, role_name)
  ])])
  roles_with_query_permissions = distinct(flatten(values(var.table_permission_names).*.query_permission_names))
  per_role_query_policy_map = zipmap(
    local.roles_with_query_permissions,
    [for role_name in local.roles_with_query_permissions : flatten([for table_name, config in var.table_configs: [
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
        module.table[table_name].table.arn,
        "${module.table[table_name].table.arn}/*",
      ]
    },
  ] if contains(lookup(var.table_permission_names, table_name, {
    add_partition_permission_names = [] 
    query_permission_names = [] 
  }).query_permission_names, role_name)
  ])])
}

resource "random_id" "addpart_role_ids" {
  for_each = local.per_role_add_partition_policy_map
  byte_length = 2
}

module glue_table_add_partition_permissions {
  source = "github.com/RLuckom/terraform_modules//aws/iam/add_policy_to_roles"
  for_each = local.per_role_add_partition_policy_map
  policy_name = "${each.key}-${random_id.addpart_role_ids[each.key].b64_url}"
  role_names = [each.key]
  policy_statements = each.value
}

resource "random_id" "query_role_ids" {
  for_each = local.per_role_query_policy_map
  byte_length = 2
}

module glue_table_query_permissions {
  source = "github.com/RLuckom/terraform_modules//aws/iam/add_policy_to_roles"
  for_each = local.per_role_query_policy_map
  policy_name = "${each.key}-${random_id.query_role_ids[each.key].b64_url}"
  role_names = [each.key]
  policy_statements = each.value
}
