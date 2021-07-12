data aws_iam_policy_document policy {
  count = length(var.role_policy) > 0 ? 1 : 0
  dynamic "statement" {
    for_each = var.role_policy
    content {
      actions   = statement.value.actions
      resources   = statement.value.resources
    }
  }
}

resource aws_iam_policy role_policy {
  count = length(var.role_policy) > 0 ? 1 : 0
  name = "${local.role_name}-policy"
  policy = data.aws_iam_policy_document.policy[0].json
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
  name = local.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "attach-policy-to-role" {
  count = length(var.role_policy) > 0 ? 1 : 0
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.role_policy[0].arn
}
