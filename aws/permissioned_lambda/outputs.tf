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
    qualified_arn = aws_lambda_function.lambda.qualified_arn
  }
}

output "permission_sets" {
  value = local.permission_sets
}

locals {
  permission_sets = {
    invoke = local.lambda_invoke
  }
}
