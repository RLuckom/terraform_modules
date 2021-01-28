output lambda_logging_prefix_role_map {
  value = zipmap(
    [var.coordinator_data.lambda_log_prefix],
    [{
      permission_type = "put_object"
      role_arns = [for x in concat(
        module.site_render,
        module.archive_function
        module.deletion_cleanup,
        module.trails_resolver,
        module.trails_updater
      ) : x.role.arn ]
    }]
  )
}

output log_delivery_prefix_notification_map {
  value = zipmap(
    [var.coordinator_data.cloudfront_log_delivery_prefix],
    [[for f in module.archive_function :
    {
      permission_type = "move_known_objects_out"
      lambda_role_arn = f.role.arn
      lambda_arn = f.lambda.arn
      name = f.lambda.function_name
      events = ["s3:ObjectCreated:*"]
      filter_prefix = var.coordinator_data.cloudfront_log_delivery_prefix
      filter_suffix = ""
    }]]
  )
}

output athena_prefix_athena_query_role_map {
  value = zipmap(
    [var.coordinator_data.cloudfront_result_prefix],
    [[for f in module.archive_function : f.role.arn]]
  )
}

output cloudfront_origin_access_principal {
  value = {
    type = "AWS"
    identifiers = module.site.*.origin_access_identity.iam_arn
  }
}
