output "table" {
  value = aws_dynamodb_table.standard_table
}

output permission_sets {
  value = {
    put_item = [
      {
        actions   = ["dynamodb:PutItem"]
        resources = [aws_dynamodb_table.standard_table.arn]
      }
    ]
    write = [
      {
        actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:BatchWriteItem"]
        resources = [aws_dynamodb_table.standard_table.arn]
      }
    ]
    read = [
      {
        actions   = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:BatchGetItem"]
        resources = [aws_dynamodb_table.standard_table.arn]
      }
    ]
    delete_item = [
      {
        actions   = ["dynamodb:DeleteItem"]
        resources = [aws_dynamodb_table.standard_table.arn]
      }
    ]
  }
}
