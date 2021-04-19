output authenticated_role {
  value = zipmap(
    keys(var.plugin_configs),
    [ for k in keys(var.plugin_configs): module.authenticated_role[k].role]
  )
}

output plugin_role_map {
  value = local.plugin_role_map
}

output identity_pool {
  value = aws_cognito_identity_pool.id_pool
}
