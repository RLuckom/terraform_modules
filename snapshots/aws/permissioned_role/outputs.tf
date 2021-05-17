output "role" {
  value = {
    arn = aws_iam_role.role.arn
    id = aws_iam_role.role.id
    name = aws_iam_role.role.name
    unique_id = aws_iam_role.role.unique_id
  }
}
