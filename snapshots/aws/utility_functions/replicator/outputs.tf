output replication_lambda {
  value = local.need_replication_lambda ? {
    role_arn = module.replication_lambda[0].role.arn 
    role_name = module.replication_lambda[0].role.name
    lambda_arn = module.replication_lambda[0].lambda.arn
  } : {
    role_arn = ""
    role_name = ""
    lambda_arn = ""
  }
}

output replication_function_permissions_needed {
  value = local.replication_function_prefix_permissions
}

output bucket_notifications {
  value = local.lambda_notifications
}

output lambda_logging_roles {
  value = module.replication_lambda.*.role.arn
}
