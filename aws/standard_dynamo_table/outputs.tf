output "table" {
  value = aws_dynamodb_table.standard_table
}

locals {
  table_and_index_arns = concat([aws_dynamodb_table.standard_table.arn], [ for v in var.global_indexes : "${aws_dynamodb_table.standard_table.arn}/index/${v.name}"])
}

output permission_sets {
  value = {
    put_item = [
      {
        actions   = ["dynamodb:PutItem"]
        resources = local.table_and_index_arns
      }
    ]
    write = [
      {
        actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:BatchWriteItem"]
        resources = local.table_and_index_arns
      }
    ]
    read = [
      {
        actions   = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:BatchGetItem"]
        resources = local.table_and_index_arns
      }
    ]
    delete_item = [
      {
        actions   = ["dynamodb:DeleteItem"]
        resources = local.table_and_index_arns
      }
    ]
  }
}
