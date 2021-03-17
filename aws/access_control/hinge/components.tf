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

  roles = {
    "authenticated" = module.authenticated_role.role.arn
  }
}

module authenticated_role {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_web_identity_role"
  role_name = "${local.name}-auth"
  role_policy = var.authenticated_policy_statements
  identity_pool_id = aws_cognito_identity_pool.id_pool.id
}
