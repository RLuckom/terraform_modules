resource aws_cognito_identity_pool id_pool {
  identity_pool_name               = local.name
  allow_unauthenticated_identities = var.allow_unauthenticated_identities

  cognito_identity_providers {
    client_id               = var.client_id
    provider_name           = var.provider_endpoint
    server_side_token_check = var.server_side_token_check
  }
}

resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.id_pool.id


  role_mapping {
    identity_provider         = "${var.provider_endpoint}:${var.client_id}"
    ambiguous_role_resolution = "Deny"
    type                      = "Rules"

    mapping_rule {
      claim      = "aud"
      match_type = "Equals"
      role_arn   = module.empty_authenticated_role.role.arn
      value      = var.client_id
    }

    dynamic "mapping_rule" {
      for_each = var.authenticated_policy_statements
      content {
        claim      = "cognito:groups"
        match_type = "Contains"
        role_arn   = module.authenticated_role[mapping_rule.key].role.arn
        value      = var.required_group
      }
    }
  }

  roles = {
    "authenticated" = module.parent_authenticated_role.role.arn
  }
}

module authenticated_role {
  for_each = var.authenticated_policy_statements
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_web_identity_role"
  role_name = "${local.name}-${each.key}-auth"
  role_policy = each.value
  identity_pool_id = aws_cognito_identity_pool.id_pool.id
}

module parent_authenticated_role {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_web_identity_role"
  role_name = "${local.name}-parent-auth"
  role_policy = [{ 
    actions = ["iam:PassRole"],
    resources = concat([module.empty_authenticated_role.role.arn], [ for k, v in var.authenticated_policy_statements : module.authenticated_role[k].role.arn])
  }]
  identity_pool_id = aws_cognito_identity_pool.id_pool.id
}

module empty_authenticated_role {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_web_identity_role"
  role_name = "${local.name}-empty-auth"
  identity_pool_id = aws_cognito_identity_pool.id_pool.id
}
