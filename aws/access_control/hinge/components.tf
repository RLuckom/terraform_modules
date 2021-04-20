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

    // When a getCredentialsForIdentity request is received by aws,
    // if it HAS a CustomRoleArn argument AND the identity is eligible for the role,
    // credentials for the role are returned.
    //
    // If it DOES NOT have a CustomRoleArn argument, aws returns the FIRST role
    // for which it is eligible (based on mapping rule order), or else the behavior
    // specified in ambiguous_role_resolution.
    //
    // That means that if we include a role with no permissions as the first rule,
    // and we make it so that all valid tokens are eligible for that role (by testing
    // whether the audience matches our client ID, which it will for all valid tokens)
    // then any getCredentialsForIdentity request that does NOT specify a CustomRoleArn
    // will be given the empty role rather than an arbitrary one.
    mapping_rule {
      claim      = "aud"
      match_type = "Equals"
      role_arn   = module.empty_authenticated_role.role.arn
      value      = var.client_id
    }

    dynamic "mapping_rule" {
      for_each = var.plugin_configs
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
  for_each = var.plugin_configs
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_web_identity_role"
  role_name = "${local.name}-${each.value.role_name_stem}-auth"
  role_policy = []
  identity_pool_id = aws_cognito_identity_pool.id_pool.id
}

module parent_authenticated_role {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_web_identity_role"
  role_name = "${local.name}-parent-auth"
  role_policy = [{ 
    actions = ["iam:PassRole"],
    resources = concat([module.empty_authenticated_role.role.arn], [ for k, v in var.plugin_configs : module.authenticated_role[k].role.arn])
  }]
  identity_pool_id = aws_cognito_identity_pool.id_pool.id
}

module empty_authenticated_role {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_web_identity_role"
  role_name = "${local.name}-empty-auth"
  identity_pool_id = aws_cognito_identity_pool.id_pool.id
}
