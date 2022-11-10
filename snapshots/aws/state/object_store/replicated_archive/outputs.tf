output replication_lambda {
  value = module.replication_lambda.replication_lambda
}

output replication_function_permissions_needed {
  value = module.replication_lambda.replication_function_permissions_needed
}

output bucket_notifications {
  value = module.replication_lambda.bucket_notifications
}

output lambda_logging_roles {
  value = module.replication_lambda.lambda_logging_roles
}
