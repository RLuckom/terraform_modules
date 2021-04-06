output "bucket" {
  value = aws_s3_bucket.bucket
}

output auto_replication_service_role_arn {
  value = local.auto_replication_role_arn
}

output replication_lambda {
  value = module.replication_lambda.replication_lambda 
}

output replication_function_permissions_needed {
  value = local.replication_function_permissions_needed
}

output lambda_logging_roles {
  value = flatten([
    module.replication_lambda.lambda_logging_roles,
  ])
}
