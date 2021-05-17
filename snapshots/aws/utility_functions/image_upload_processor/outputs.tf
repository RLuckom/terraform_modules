output lambda {
  value = module.image_processing_lambda.lambda
}

output lambda_role {
  value = module.image_processing_lambda.role
}

output lambda_notification_config {
  value = {
    lambda_arn = module.image_processing_lambda.lambda.arn
    lambda_name = module.image_processing_lambda.lambda.function_name
    lambda_role_arn = module.image_processing_lambda.role.arn
    permission_type     = "read_and_tag_known"
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.io_config.input_path
    filter_suffix       = ""
  }
}

output image_destination_permission_needed {
  value = {
    permission_type = "put_object"
    prefix = var.io_config.output_path
    arns = [module.image_processing_lambda.role.arn]
  }
}
