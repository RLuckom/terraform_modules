output render_function {
  value = {
    arn = module.site_render.lambda.arn
    name = module.site_render.lambda.function_name
    role_arn = module.site_render.role.arn
  }
}

output functions {
  values = zipmap(
    [for name in ["render", "trails_updater", "trails_resolver", "deletion_cleanup"] : "${var.purpose_descriptor}-${name}"],
    [for name in ["render", "trails_updater", "trails_resolver", "deletion_cleanup"] : {
      scope = var.purpose_descriptor
      action = name
      region = local.passthroughs[name].region
    }]
  )
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

output cloudfront_log_delivery_identity {
  value = module.site.origin_access_identity
}
