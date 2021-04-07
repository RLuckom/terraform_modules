output lambda {
  value = local.need_lambda ? {
    role_arn = module.lambda[0].role.arn 
    role_name = module.lambda[0].role.name
    lambda_arn = module.lambda[0].lambda.arn
  } : {
    role_arn = ""
    role_name = ""
    lambda_arn = ""
  }
}

output bucket_notifications {
  value = local.splitter_notifications
}

output lambda_logging_roles {
  value = module.lambda.*.role.arn
}

output manual_notifications {
  value = local.need_lambda
}


