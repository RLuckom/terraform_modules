output user_pool {
  value = aws_cognito_user_pool.user_pool
}

output user_group {
  value = aws_cognito_user_group.user_group
}

output user_pool_client {
  value = aws_cognito_user_pool_client.client
}

output user_pool_domain {
  value = aws_cognito_user_pool_domain.domain
}

// safe from circular references,
// unlike above
output auth_domain_name {
  value = local.cognito_domain
}
