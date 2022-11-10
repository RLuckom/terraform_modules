output "table" {
  value = aws_dynamodb_table.standard_table
}

output "table_arn" {
  value = local.table_arn
}

output "table_name" {
  value = local.table_name
}

output "table_metadata" {
  value = {
    name = local.table_name
    region = var.region
    arn = local.table_arn
  }
}
