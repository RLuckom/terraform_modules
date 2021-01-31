output lambda_logging_prefix_role_map {
  value = zipmap(
    [
      var.coordinator_data.lambda_log_prefix,
    ],
    [
      {
        permission_type = "put_object"
        role_arns = flatten([
          module.site_render.*.role.arn,
          module.deletion_cleanup.*.role.arn,
          module.trails_resolver.*.role.arn,
          module.trails_updater.*.role.arn
        ])
      },
    ]
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
