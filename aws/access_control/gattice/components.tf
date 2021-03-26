resource random_id bucket_suffix {
  byte_length = 16
}

resource aws_s3_bucket stage_login_functions {
  bucket = "stage-functions-${lower(replace(random_id.bucket_suffix.b64_url, "_", ""))}"
  acl    = "private"
  force_destroy = true
}

module cognito_fn_template {
  source = "github.com/RLuckom/terraform_modules//protocols/boundary_oauth"
  token_issuer = var.token_issuer
  http_header_values = var.http_header_values
  client_id = var.client_id
  client_secret = var.client_secret
  nonce_signing_secret = var.nonce_signing_secret
  auth_domain = local.auth_domain
  user_group_name = var.user_group_name
  log_source = var.log_source
  log_source_instance = var.log_source_instance
  component = var.component
  bucket_config = {
    bucket = aws_s3_bucket.stage_login_functions.id
    prefix = ""
    supplied = true
    credentials_file = var.aws_credentials_file
  }
}

module check_auth {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  publish = true
  preuploaded_source = module.cognito_fn_template.s3_objects.check_auth
  timeout_secs = module.cognito_fn_template.function_configs.function_defaults.timeout_secs
  mem_mb = module.cognito_fn_template.function_configs.function_defaults.mem_mb
  role_service_principal_ids = module.cognito_fn_template.function_configs.function_defaults.role_service_principal_ids
  lambda_details = {
    action_name = module.cognito_fn_template.function_configs.check_auth.details.action_name
    scope_name = var.security_scope
    policy_statements = []
  }
  depends_on = [module.cognito_fn_template]
}

module move_cookie_to_auth_header {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  publish = true
  preuploaded_source = module.cognito_fn_template.s3_objects.move_cookie_to_auth_header
  timeout_secs = module.cognito_fn_template.function_configs.function_defaults.timeout_secs
  mem_mb = module.cognito_fn_template.function_configs.function_defaults.mem_mb
  role_service_principal_ids = module.cognito_fn_template.function_configs.function_defaults.role_service_principal_ids
  lambda_details = {
    action_name = module.cognito_fn_template.function_configs.move_cookie_to_auth_header.details.action_name
    scope_name = var.security_scope
    policy_statements = []
  }
  depends_on = [module.cognito_fn_template]
}

module http_headers {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  publish = true
  preuploaded_source = module.cognito_fn_template.s3_objects.http_headers
  timeout_secs = module.cognito_fn_template.function_configs.function_defaults.timeout_secs
  mem_mb = module.cognito_fn_template.function_configs.function_defaults.mem_mb
  role_service_principal_ids = module.cognito_fn_template.function_configs.function_defaults.role_service_principal_ids
  lambda_details = {
    action_name = module.cognito_fn_template.function_configs.http_headers.details.action_name
    scope_name = var.security_scope
    policy_statements = []
  }
  depends_on = [module.cognito_fn_template]
}

module sign_out {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  publish = true
  preuploaded_source = module.cognito_fn_template.s3_objects.sign_out
  timeout_secs = module.cognito_fn_template.function_configs.function_defaults.timeout_secs
  mem_mb = module.cognito_fn_template.function_configs.function_defaults.mem_mb
  role_service_principal_ids = module.cognito_fn_template.function_configs.function_defaults.role_service_principal_ids
  lambda_details = {
    action_name = module.cognito_fn_template.function_configs.sign_out.details.action_name
    scope_name = var.security_scope
    policy_statements = []
  }
  depends_on = [module.cognito_fn_template]
}

module refresh_auth {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  publish = true
  preuploaded_source = module.cognito_fn_template.s3_objects.refresh_auth
  timeout_secs = module.cognito_fn_template.function_configs.function_defaults.timeout_secs
  mem_mb = module.cognito_fn_template.function_configs.function_defaults.mem_mb
  role_service_principal_ids = module.cognito_fn_template.function_configs.function_defaults.role_service_principal_ids
  lambda_details = {
    action_name = module.cognito_fn_template.function_configs.refresh_auth.details.action_name
    scope_name = var.security_scope
    policy_statements = []
  }
  depends_on = [module.cognito_fn_template]
}

module parse_auth {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  publish = true
  preuploaded_source = module.cognito_fn_template.s3_objects.parse_auth
  timeout_secs = module.cognito_fn_template.function_configs.function_defaults.timeout_secs
  mem_mb = module.cognito_fn_template.function_configs.function_defaults.mem_mb
  role_service_principal_ids = module.cognito_fn_template.function_configs.function_defaults.role_service_principal_ids
  lambda_details = {
    action_name = module.cognito_fn_template.function_configs.parse_auth.details.action_name
    scope_name = var.security_scope
    policy_statements = []
  }
  depends_on = [module.cognito_fn_template]
}
