output render_function {
  value = {
    arn = module.site_render.lambda.arn
    name = module.site_render.lambda.function_name
    role_arn = module.site_render.role.arn
  }
}

output deletion_cleanup_function {
  value = {
    arn = module.deletion_cleanup.lambda.arn
    name = module.deletion_cleanup.lambda.function_name
    role_arn = module.deletion_cleanup.role.arn
  }
}

output trails_resolver_function {
  value = {
    arn = module.trails_resolver.lambda.arn
    name = module.trails_resolver.lambda.function_name
    role_arn = module.trails_resolver.role.arn
  }
}

output trails_updater_function {
  value = {
    arn = module.trails_updater.lambda.arn
    name = module.trails_updater.lambda.function_name
    role_arn = module.trails_updater.role.arn
  }
}
