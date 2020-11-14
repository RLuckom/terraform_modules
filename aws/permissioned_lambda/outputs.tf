output "role" {
  value = module.lambda_role.role
}

output "lambda" {
  value = {
    function_name = aws_lambda_function.lambda.function_name
    arn = aws_lambda_function.lambda.arn
    timeout = aws_lambda_function.lambda.timeout
    environment = var.environment_var_map
    tags = aws_lambda_function.lambda.tags
  }
}

output "log_group" {
  value = {
    arn = aws_cloudwatch_log_group.lambda_log_group.arn
    name = aws_cloudwatch_log_group.lambda_log_group.name
    name_prefix = aws_cloudwatch_log_group.lambda_log_group.name_prefix
    kms_key_id = aws_cloudwatch_log_group.lambda_log_group.kms_key_id
    tags = aws_cloudwatch_log_group.lambda_log_group.tags
  }
}

output "permission_sets" {
  value = local.permission_sets
}

locals {
  permission_sets = {
    invoke = [{
      actions   =  [
        "lambda:InvokeFunction"
      ]
      resources = [
        aws_lambda_function.lambda.arn,
      ]
    }]
  }
}
