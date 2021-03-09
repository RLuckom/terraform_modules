module cognito_fn_template {
  source = "github.com/RLuckom/terraform_modules//protocols/boundary_oauth"
  token_issuer = var.token_issuer
  client_id = var.client_id
  client_secret = var.client_secret
  nonce_signing_secret = var.nonce_signing_secret
  auth_domain = var.auth_domain
  user_group_name = var.user_group_name
  log_source = var.log_source
  log_source_instance = var.log_source_instance
  component = var.component
}

module check_auth {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  publish = true
  timeout_secs = module.cognito_fn_template.function_configs.function_defaults.timeout_secs
  mem_mb = module.cognito_fn_template.function_configs.function_defaults.mem_mb
  role_service_principal_ids = module.cognito_fn_template.function_configs.function_defaults.role_service_principal_ids
  source_contents = module.cognito_fn_template.function_configs.check_auth.source_contents
  lambda_details = {
    action_name = module.cognito_fn_template.function_configs.check_auth.details.action_name
    scope_name = var.security_scope
    policy_statements = []
  }
  local_source_directory = module.cognito_fn_template.directory
}

module http_headers {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  publish = true
  timeout_secs = module.cognito_fn_template.function_configs.function_defaults.timeout_secs
  mem_mb = module.cognito_fn_template.function_configs.function_defaults.mem_mb
  role_service_principal_ids = module.cognito_fn_template.function_configs.function_defaults.role_service_principal_ids
  source_contents = module.cognito_fn_template.function_configs.http_headers.source_contents
  lambda_details = {
    action_name = module.cognito_fn_template.function_configs.http_headers.details.action_name
    scope_name = var.security_scope
    policy_statements = []
  }
  local_source_directory = module.cognito_fn_template.directory
}

module sign_out {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  publish = true
  timeout_secs = module.cognito_fn_template.function_configs.function_defaults.timeout_secs
  mem_mb = module.cognito_fn_template.function_configs.function_defaults.mem_mb
  role_service_principal_ids = module.cognito_fn_template.function_configs.function_defaults.role_service_principal_ids
  source_contents = module.cognito_fn_template.function_configs.sign_out.source_contents
  lambda_details = {
    action_name = module.cognito_fn_template.function_configs.sign_out.details.action_name
    scope_name = var.security_scope
    policy_statements = []
  }
  local_source_directory = module.cognito_fn_template.directory
}

module refresh_auth {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  publish = true
  timeout_secs = module.cognito_fn_template.function_configs.function_defaults.timeout_secs
  mem_mb = module.cognito_fn_template.function_configs.function_defaults.mem_mb
  role_service_principal_ids = module.cognito_fn_template.function_configs.function_defaults.role_service_principal_ids
  source_contents = module.cognito_fn_template.function_configs.refresh_auth.source_contents
  lambda_details = {
    action_name = module.cognito_fn_template.function_configs.refresh_auth.details.action_name
    scope_name = var.security_scope
    policy_statements = []
  }
  local_source_directory = module.cognito_fn_template.directory
}

module parse_auth {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  publish = true
  timeout_secs = module.cognito_fn_template.function_configs.function_defaults.timeout_secs
  mem_mb = module.cognito_fn_template.function_configs.function_defaults.mem_mb
  role_service_principal_ids = module.cognito_fn_template.function_configs.function_defaults.role_service_principal_ids
  source_contents = module.cognito_fn_template.function_configs.parse_auth.source_contents
  lambda_details = {
    action_name = module.cognito_fn_template.function_configs.parse_auth.details.action_name
    scope_name = var.security_scope
    policy_statements = []
  }
  local_source_directory = module.cognito_fn_template.directory
}
