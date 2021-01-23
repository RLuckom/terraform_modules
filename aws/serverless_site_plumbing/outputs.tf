output logging_lambda_role_arns {
  value = [
    module.site_render.role.arn,
    module.archive_function.role.arn,
    module.deletion_cleanup.role.arn,
    module.trails_resolver.role.arn,
    module.trails_updater.role.arn,
  ]
}

output archive_function {
  value = {
    arn = module.archive_function.lambda.arn
    name = module.archive_function.lambda.function_name
    role_arn = module.archive_function.role.arn
    role_name = module.archive_function.role.name
  }
}

output archive_function_notification_config {
  value = {
    lambda_arn = module.archive_function.lambda.arn
    lambda_name = module.archive_function.lambda.function_name
    lambda_role_arn = module.archive_function.role.arn
    permission_type = "move_objects_out"
    events = ["s3:ObjectCreated:*"]
    filter_prefix = var.coordinator_data.cloudfront_log_delivery_prefix
    filter_suffix = ""
  }
}

output glue_table_permission_names {
  value = zipmap([var.coordinator_data.glue_table_name],
  [{
  add_partition_permission_names = [module.archive_function.role.name]
}])
}

output render_function {
  value = {
    arn = module.site_render.lambda.arn
    name = module.site_render.lambda.function_name
    role_arn = module.site_render.role.arn
    role_name = module.site_render.role.name
  }
}

output functions {
  value = zipmap(
    [for name in ["render", "trails_updater", "trails_resolver", "deletion_cleanup"] : "${var.coordinator_data.scope}-${name}"],
    [for name in ["render", "trails_updater", "trails_resolver", "deletion_cleanup"] : {
      scope = var.coordinator_data.scope
      action = name
    }]
  )
}

output deletion_cleanup_function {
  value = {
    arn = module.deletion_cleanup.lambda.arn
    name = module.deletion_cleanup.lambda.function_name
    role_arn = module.deletion_cleanup.role.arn
    role_name = module.deletion_cleanup.role.name
  }
}

output trails_resolver_function {
  value = {
    arn = module.trails_resolver.lambda.arn
    name = module.trails_resolver.lambda.function_name
    role_arn = module.trails_resolver.role.arn
    role_name = module.trails_resolver.role.name
  }
}

output trails_updater_function {
  value = {
    arn = module.trails_updater.lambda.arn
    name = module.trails_updater.lambda.function_name
    role_arn = module.trails_updater.role.arn
    role_name = module.trails_updater.role.name
  }
}

output cloudfront_origin_access_identity {
  value = module.site.origin_access_identity
}
