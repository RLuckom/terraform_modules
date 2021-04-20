data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

output "role" {
  value = {
    arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.role_name}"
    id = var.role_name
    name = var.role_name
  }
}

output unique_id {
  value = aws_iam_role.role.unique_id
}
