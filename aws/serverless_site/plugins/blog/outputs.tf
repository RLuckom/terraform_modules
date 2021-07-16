output plugin_relative_lambda_notifications {
  value = [
    {
      lambda_arn = module.process_image_uploads.lambda_notification_config.lambda_arn
      lambda_name = module.process_image_uploads.lambda_notification_config.lambda_name
      lambda_role_arn = module.process_image_uploads.lambda_notification_config.lambda_role_arn
      events = module.process_image_uploads.lambda_notification_config.events
      plugin_relative_filter_prefix = "/img/"
      filter_suffix = module.process_image_uploads.lambda_notification_config.filter_suffix
      permission_type = module.process_image_uploads.lambda_notification_config.permission_type
    },
    {
      lambda_arn = module.post_entry_lambda.lambda.arn
      lambda_name = module.post_entry_lambda.lambda.function_name
      lambda_role_arn = module.post_entry_lambda.role.arn
      events = ["s3:ObjectCreated:*"]
      plugin_relative_filter_prefix = "/posts/"
      filter_suffix = ".md"
      permission_type = "read_and_tag_known"
    },
  ]
}

output plugin_relative_lambda_origins {
  value = []
}

output plugin_relative_bucket_host_permissions_needed {
  value = [
    {
      permission_type = "put_object"
      plugin_relative_key = "/img/"
      role_arn = module.process_image_uploads.lambda_role.arn
    },
    {
      permission_type = "delete_object"
      plugin_relative_key = "/img/"
      role_arn = module.post_entry_lambda.role.arn
    },
    {
      permission_type = "read_and_tag_known"
      plugin_relative_key = "/img/"
      role_arn = module.post_entry_lambda.role.arn
    },
    {
      permission_type = "read_and_tag_known"
      plugin_relative_key = "/posts/"
      role_arn = module.post_entry_lambda.role.arn
    },
    {
      permission_type = "read_and_tag_known"
      plugin_relative_key = "/posts/"
      role_arn = null
    },
    {
      permission_type = "put_object"
      plugin_relative_key = "/posts/"
      role_arn = module.post_entry_lambda.role.arn
    },
    {
      permission_type = "delete_object"
      plugin_relative_key = "/posts/"
      role_arn = module.post_entry_lambda.role.arn
    },
  ]
}

output plugin_relative_bucket_upload_permissions_needed {
  value = [
    {
      permission_type = "put_object"
      plugin_relative_key = "/img/"
      role_arn = null
    },
    {
      permission_type = "put_object"
      plugin_relative_key = "/posts/"
      role_arn = null
    },
  ]
}

output plugin_relative_bucket_list_permissions_needed {
  value = [
    {
      plugin_relative_key = "/posts/"
      role_arn = null
    },
    {
      plugin_relative_key = "/img/"
      role_arn = null
    },
    {
      plugin_relative_key = "/img/"
      role_arn = module.post_entry_lambda.role.arn
    },
    {
      plugin_relative_key = "/posts/"
      role_arn = module.post_entry_lambda.role.arn
    },
  ]
}

output static_config {
  value = {
    api_name = var.name
    display_name = var.name
    role_name_stem = var.name
  }
}

output plugin_config {
  value = var.plugin_config
}

output blog_site_bucket_name {
  value = module.blog_site.website_bucket_name
}
output additional_connect_sources_required {
  value = [
    "https://s3.amazonaws.com", 
    "https://${module.blog_site.website_bucket_name}.s3.amazonaws.com", "https://${var.plugin_config.bucket_name}.s3.amazonaws.com",
    "https://dynamodb.${var.region}.amazonaws.com/",
  ]
}

output lambda_logging_arns {
  value = concat([
    module.process_image_uploads.lambda_role.arn,
    module.post_entry_lambda.role.arn,
  ], module.blog_site.lambda_logging_roles)
}
