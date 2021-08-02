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
    metric_table = var.coordinator_data.metric_table
    authenticated_role = module.cognito_identity_management.authenticated_role[replace(k, "/", "")]
    aws_credentials_endpoint = var.get_access_creds_path_for_lambda_origin
    source_root = "${local.plugin_root}/${replace(k, "/", "")}/"
    api_root = "${local.api_root}/${local.plugin_root}/${replace(k, "/", "")}/"
    upload_root = "${local.upload_root}/${local.plugin_root}/${replace(k, "/", "")}/"
    setup_storage_root = "${local.setup_storage_root}/${local.plugin_root}/${replace(k, "/", "")}/"
    backend_readonly_root = "${local.backend_readonly_root}/${local.plugin_root}/${replace(k, "/", "")}/"
    backend_readwrite_root = "${local.backend_readwrite_root}/${local.plugin_root}/${replace(k, "/", "")}/"
    hosting_root = "${local.asset_hosting_root}/${local.plugin_root}/${replace(k, "/", "")}/"
  }])
}

output site_resources {
  value = module.admin_site_frontpage.site_resources
}

output plugin_authenticated_roles {
  value = zipmap(
    [for k in keys(var.plugin_configs) : replace(k, "/", "")],
    [for name in [for k in keys(var.plugin_configs) : replace(k, "/", "")]:
    module.cognito_identity_management.authenticated_role[name]
  ])
}
