variable role_names {
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

      actions = statement.value.actions

      resources = statement.value.resources
    }
  }
}

resource aws_iam_policy policy {
  count = length(var.role_names) > 0 ? 1 : 0
  name   = var.policy_name
  policy = data.aws_iam_policy_document.policy_doc.json
}

resource aws_iam_role_policy_attachment attachments {
  count = length(var.role_names)
  role       = var.role_names[count.index]
  policy_arn = aws_iam_policy.policy[0].arn
}
