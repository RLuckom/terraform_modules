data aws_iam_policy_document policy {
  dynamic "statement" {
    for_each = var.role_policy
    content {
      actions   = statement.value.actions
      resources   = statement.value.resources
    }
  }
}

resource aws_iam_policy role_policy {
  name = "${var.role_name}-policy"
  policy = data.aws_iam_policy_document.policy.json
}

data aws_iam_policy_document assume_role_policy {
  statement {
    actions   =  [
      "sts:AssumeRoleWithWebIdentity"
    ]
    principals {
      type = "Federated"
      identifiers = ["cognito-identity.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "cognito-identity.amazonaws.com:aud"

      values = [
        var.identity_pool_id
      ]
    }
    condition {
      test     = "ForAnyValue:StringLike"
      variable = "cognito-identity.amazonaws.com:amr"

      values = [
        var.require_authenticated ? "authenticated" : "unauthenticated"
      ]
    }
  }
}

resource aws_iam_role role {
  name = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "attach-policy-to-role" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.role_policy.arn
}
