output lambda_logging_roles {
  value = flatten([
    module.site_render.role.arn,
  ])
}

output cloudfront_origin_access_principal {
  value = {
    type = "AWS"
    identifiers = module.site.origin_access_identity.iam_arn
  }
}

output website_bucket_name {
  value = module.website_bucket.bucket_name
}

output routing {
  value = local.routing
}

output system_id {
  value = local.system_id
}

output table_name {
  value = module.trails_table.table_name
}
