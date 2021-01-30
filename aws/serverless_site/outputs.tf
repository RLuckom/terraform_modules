output lambda_logging_prefix_role_map {
  value = zipmap(
    [
      var.coordinator_data.lambda_log_prefix,
      var.coordinator_data.cloudfront_log_storage_prefix,
    ],
    [
      {
        permission_type = "put_object"
        role_arns = flatten([
          module.site_render.*.role.arn,
          module.archive_function.*.role.arn,
          module.deletion_cleanup.*.role.arn,
          module.trails_resolver.*.role.arn,
          module.trails_updater.*.role.arn
        ])
      },
      {
        permission_type = "put_object"
        role_arns = flatten([
          module.archive_function.*.role.arn,
        ])
      },
    ]
  )
}

output log_delivery_prefix_notification_map {
  value = zipmap(
    [var.coordinator_data.cloudfront_log_delivery_prefix],
    [length(module.archive_function) > 0 ? 
    {
      permission_type = "move_known_objects_out"
      lambda_role_arn = module.archive_function[0].role.arn
      lambda_arn = module.archive_function[0].lambda.arn
      lambda_name = module.archive_function[0].lambda.function_name
      name = module.archive_function[0].lambda.function_name
      events = ["s3:ObjectCreated:*"]
      filter_prefix = var.coordinator_data.cloudfront_log_delivery_prefix
      filter_suffix = ""
    } : null]
  )
}

output athena_prefix_athena_query_role_map {
  value = zipmap(
    [var.coordinator_data.cloudfront_result_prefix],
    [[for f in module.archive_function : f.role.arn]]
  )
}

output glue_permission_name_map {
  value = zipmap(
    [var.coordinator_data.glue_table_name],
    [length(module.archive_function) > 0 ? 
    {
      add_partition_permission_names = [module.archive_function[0].role.name]
    } : null]
  )
}

output cloudfront_origin_access_principal {
  value = {
    type = "AWS"
    identifiers = module.site.*.origin_access_identity.iam_arn
  }
}

locals {
  cloudfront_origin_access_principal = {
    type = "AWS"
    identifiers = module.site.*.origin_access_identity.iam_arn
  }
}
