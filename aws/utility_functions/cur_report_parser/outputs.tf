output lambda {
  value = module.cur_parser_lambda.lambda
}

output role {
  value = module.cur_parser_lambda.role
}

output lambda_notification_config {
  value = {
    lambda_arn = module.cur_parser_lambda.lambda.arn
    lambda_name = module.cur_parser_lambda.lambda.function_name
    lambda_role_arn = module.cur_parser_lambda.role.arn
    permission_type     = "read_and_tag_known"
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.io_config.input_config.prefix
    filter_suffix       = ".csv.gz"
  }
}

output destination_permission_needed {
  value = {
    permission_type = "put_object"
    prefix = var.io_config.output_config.prefix
    arns = [module.cur_parser_lambda.role.arn]
  }
}

output report_summary_key {
  value = local.report_summary_key
}
