variable role_arns {
  type = list(string)
}

variable policy_statements {
  type = list(object({
    actions = list(string)
    resources = list(string)
  }))
}

variable policy_name {
  type = string
}

data aws_iam_policy_document policy_doc {
  dynamic "statement" {
    for_each = var.policy_statements
    content {

      actions = each.value.actions

      resources = each.value.resources
    }
  }
}

resource aws_iam_policy policy {
  name   = var.policy_name
  policy = data.aws_iam_policy_document.policy_doc.json
}

resource aws_iam_role_policy_attachment attachments {
  count = length(var.role_arns)
  role       = var.role_arns[count.index]
  policy_arn = aws_iam_policy.policy.arn
}
