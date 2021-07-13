module cognito_user_management {
  source = "../../state/user_mgmt/stele"
  unique_suffix = var.unique_suffix
  system_id = var.system_id
  token_validities = var.token_validities
  protected_domain_routing = var.coordinator_data.routing
  additional_protected_domains = var.additional_protected_domains
  user_group_name = var.user_group_name
  user_email = var.user_email
}

module cognito_identity_management {
  source = "../../access_control/hinge"
  unique_suffix = var.unique_suffix
  account_id = var.account_id
  region = var.region
  system_id = var.system_id
  required_group = var.user_group_name
  client_id               = module.cognito_user_management.user_pool_client.id
  provider_endpoint           = module.cognito_user_management.user_pool.endpoint
  plugin_configs = var.plugin_static_configs
}

resource random_password nonce_signing_secret {
  length = 16
  override_special = "-._~"
}

module access_control_functions {
  source = "../../access_control/gattice"
  unique_suffix = var.unique_suffix
  account_id = var.account_id
  region = var.region
  token_issuer = "https://${module.cognito_user_management.user_pool.endpoint}"
  client_id = module.cognito_user_management.user_pool_client.id
  security_scope = var.system_id.security_scope
  client_secret = module.cognito_user_management.user_pool_client.client_secret
  nonce_signing_secret = random_password.nonce_signing_secret.result
  protected_domain_routing = var.coordinator_data.routing
  user_group_name = var.user_group_name
  http_header_values = merge(var.default_static_headers,
  {
    "Content-Security-Policy" = var.root_csp
  })
  http_header_values_by_plugin = zipmap(
    keys(local.plugin_configs),
    [ for config in values(local.plugin_configs) : config.http_header_values]
  )
}

module get_access_creds {
  source = "../../access_control/cognito_to_aws_creds"
  unique_suffix = var.unique_suffix
  account_id = var.account_id
  region = var.region
  identity_pool_id = module.cognito_identity_management.identity_pool.id
  user_pool_endpoint = module.cognito_user_management.user_pool.endpoint
  api_path = var.get_access_creds_path_for_lambda_origin
  gateway_name_stem = local.gateway_name_stem
  client_id = module.cognito_user_management.user_pool_client.id
  aws_sdk_layer = local.aws_sdk_layer_config
  plugin_role_map = module.cognito_identity_management.plugin_role_map
}

module apigateway_dispatcher {
  source = "../../access_control/apigateway_dispatcher"
  unique_suffix = var.unique_suffix
  account_id = var.account_id
  region = var.region
  identity_pool_id = module.cognito_identity_management.identity_pool.id
  user_pool_endpoint = module.cognito_user_management.user_pool.endpoint
  client_id = module.cognito_user_management.user_pool_client.id
  aws_sdk_layer = local.aws_sdk_layer_config
  plugin_role_map = module.cognito_identity_management.plugin_role_map
  route_to_function_name_map = local.route_to_function_name_map
}

module admin_site_frontpage {
  source = "../../../themes/icknield/admin_site_ui"
  unique_suffix = var.unique_suffix
  plugin_configs = [for name, config in var.plugin_static_configs : {
    name = name
    slug = config.display_name
  }]
  admin_running_material = {
    site_root_url = "/"
    site_title = var.admin_site_title == "" ? "${var.system_id.security_scope}-${var.system_id.subsystem_name} admin" : var.admin_site_title
    site_description = var.admin_site_description
    nav_menu_items = [for name, config in var.plugin_static_configs : {
      link = "/plugins/${trimprefix(config.api_name, "/")}/index.html"
      api_name = config.api_name
      title = config.display_name
    }]
  }
}

module admin_site {
  source = "../capstan"
  unique_suffix = var.unique_suffix
  account_id = var.account_id
  need_website_bucket_policy_override = var.need_website_bucket_policy_override
  region = var.region
  file_configs = concat(
    module.admin_site_frontpage.files,
    flatten(values(local.plugin_configs).*.file_configs)
  )
  lambda_authorizers = module.get_access_creds.lambda_authorizer_config
  forbidden_website_paths = var.forbidden_website_paths
  lambda_origins = concat(
    module.get_access_creds.lambda_origins,
    flatten(values(local.plugin_configs).*.lambda_origins)
  )
  website_bucket_prefix_object_permissions = concat(
    flatten(values(local.plugin_bucket_permissions_needed)),
    var.archive_system.bucket_permissions_needed
  )
  website_bucket_prefix_list_permissions = flatten(values(local.plugin_bucket_list_permissions_needed))
  website_bucket_lambda_notifications = concat(
    flatten(values(local.plugin_configs).*.upload_path_lambda_notifications),
    flatten(values(local.plugin_configs).*.storage_path_lambda_notifications),
    var.archive_system.lambda_notifications
  )

  website_bucket_cors_rules = [{
    allowed_headers = ["authorization", "content-md5", "content-type", "x-amz-copy-source", "cache-control", "x-amz-content-sha256", "x-amz-date", "x-amz-security-token", "x-amz-user-agent"]
    allowed_methods = ["PUT", "GET"]
    allowed_origins = ["https://${var.coordinator_data.routing.domain}"]
    expose_headers = ["ETag"]
    max_age_seconds = 3000
  }]

  access_control_function_qualified_arns = [module.access_control_functions.access_control_function_qualified_arns]
  coordinator_data = var.coordinator_data
  subject_alternative_names = var.subject_alternative_names
}
