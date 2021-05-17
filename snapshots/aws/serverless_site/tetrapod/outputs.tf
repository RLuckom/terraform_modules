output lambda_logging_roles {
  value = flatten([
    module.site_render.*.role.arn,
    module.deletion_cleanup.*.role.arn,
    module.trails_resolver.*.role.arn,
    module.trails_updater.*.role.arn
  ])
}

output cloudfront_origin_access_principal {
  value = {
    type = "AWS"
    identifiers = module.site.*.origin_access_identity.iam_arn
  }
}

output website_bucket_name {
  value = local.site_bucket
}

output routing {
  value = local.routing
}

output system_id {
  value = local.system_id
}
