output "table" {
  value = aws_dynamodb_table.standard_table
}

output "table_arn" {
  value = "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${local.table_name}"
}

output "table_name" {
  value = local.table_name
}
