output "role" {
  value = {
    arn = "arn:aws:iam::${var.account_id}:role/${local.role_name}"
    id = local.role_name
    name = local.role_name
  }
}

output unique_id {
  value = aws_iam_role.role.unique_id
}
