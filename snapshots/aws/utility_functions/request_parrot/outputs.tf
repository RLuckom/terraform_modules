output role {
  value = module.request_parrot.role
}

output lambda {
  value = module.request_parrot.lambda
}

output lambda_logging_roles {
  value = module.request_parrot.role.arn
}
