output authenticated_role {
  value = module.authenticated_role.role
}

output identity_pool {
  value = aws_cognito_identity_pool.id_pool
}
