output authenticated_role {
  value = zipmap(
    keys(var.authenticated_policy_statements),
    [ for k in keys(var.authenticated_policy_statements): module.authenticated_role[k].role]
  )
}

output plugin_role_map {
  value = local.plugin_role_map
}

output identity_pool {
  value = aws_cognito_identity_pool.id_pool
}
