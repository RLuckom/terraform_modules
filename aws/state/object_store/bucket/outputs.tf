output "bucket" {
  value = aws_s3_bucket.bucket
}

output auto_replication_service_role_arn {
  value = local.auto_replication_role_arn
}

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
  value = local.replication_function_permissions_needed
}

output lambda_logging_roles {
  value = flatten([
    module.replication_lambda.*.role.arn,
  ])
}
