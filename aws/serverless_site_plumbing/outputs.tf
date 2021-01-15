output render_function {
  value = {
    arn = module.site_render.lambda.arn
    name = module.site_render.lambda.function_name
    role_arn = module.site_render.role.arn
  }
}

output deletion_function {
  value = {
    arn = module.deletion_cleanup.lambda.arn
    name = module.deletion_cleanup.lambda.function_name
    role_arn = module.deletion_cleanup.role.arn
  }
}
