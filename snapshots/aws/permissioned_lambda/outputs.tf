output "role" {
  value = module.lambda_role.role
}

output "lambda" {
  value = {
    function_name = local.scoped_lambda_name
    arn = local.lambda_arn
    timeout = var.timeout_secs
    environment = var.environment_var_map
  }
}

output "qualified_arn" {
  value = aws_lambda_function.lambda.qualified_arn
}

output "permission_sets" {
  value = local.permission_sets
}

locals {
  permission_sets = {
    invoke = local.lambda_invoke
  }
}
