output "table" {
  value = aws_dynamodb_table.standard_table
}

output "table_name" {
  value = local.table_name
}
