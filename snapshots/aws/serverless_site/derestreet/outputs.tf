output human_attention_archive_config {
  value = {
    bucket = module.admin_site.website_bucket_name
    prefix = "${local.upload_root}/"
    suffix = ""
    filter_tags = {}
    completion_tags = var.archive_tags
    storage_class = var.archive_storage_class
  }
}

output website_config {
  value = {
    bucket_name = module.admin_site.website_bucket_name
    domain = module.admin_site.routing.domain
  }
}

output plugin_config {
  value = zipmap(
    keys(var.plugin_static_configs),
    [for k, v in var.plugin_static_configs : {
    bucket_name = module.admin_site.website_bucket_name
    domain = module.admin_site.routing.domain
    authenticated_role = module.cognito_identity_management.authenticated_role[replace(k, "/", "")]
    aws_credentials_endpoint = var.get_access_creds_path_for_lambda_origin
    source_root = "${local.plugin_root}/${replace(k, "/", "")}/"
    api_root = "${local.api_root}/${local.plugin_root}/${replace(k, "/", "")}/"
    upload_root = "${local.upload_root}/${local.plugin_root}/${replace(k, "/", "")}/"
    hosting_root = "${local.asset_hosting_root}/${local.plugin_root}/${replace(k, "/", "")}/"
  }])
}

output default_styles_path {
  value = module.admin_site_frontpage.default_styles_path
}

output plugin_authenticated_roles {
  value = zipmap(
    [for k in keys(var.plugin_configs) : replace(k, "/", "")],
    [for name in [for k in keys(var.plugin_configs) : replace(k, "/", "")]:
    module.cognito_identity_management.authenticated_role[name]
  ])
}
