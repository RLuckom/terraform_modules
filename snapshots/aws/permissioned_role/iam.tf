data "aws_iam_policy_document" "policy" {
  dynamic "statement" {
    for_each = var.role_policy
    content {
      actions   = statement.value.actions
      resources   = statement.value.resources
    }
  }
}

resource "aws_iam_policy" "role_policy" {
  name = "${var.role_name}-policy"
  policy = data.aws_iam_policy_document.policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions   =  [
      "sts:AssumeRole"
    ]
    dynamic "principals" {
      for_each = var.principals 
      content {
        type = principals.value.type
        identifiers = principals.value.identifiers
      }
    }
  }
}

resource "aws_iam_role" "role" {
  name = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "attach-policy-to-role" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.role_policy.arn
}
