resource null_resource uploaded_objects {
  count = var.bucket_config.supplied ? 1 : 0
  triggers = {
    source = local.source_hash
  }

  provisioner "local-exec" {
    command = templatefile("${path.module}/upload_populated.sh",
    {
      rendered_index = local.rendered_index
      bucket = var.bucket_config.bucket
      prefix = var.bucket_config.prefix
      version = local.version
    })
    environment = {
      AWS_SHARED_CREDENTIALS_FILE = var.bucket_config.credentials_file == "" ? "/.aws/credentials" : var.bucket_config.credentials_file
    }
    working_dir = path.module
  }
}

module check_auth {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_lambda"
  unique_suffix = var.unique_suffix
  account_id = var.account_id
  region = "us-east-1"
  publish = true
  preuploaded_source = {
    supplied = true
    bucket = var.bucket_config.bucket
    path = trimprefix("${trimsuffix(var.bucket_config.prefix, "/")}/check_auth_${local.version}.zip", "/")
  }
  timeout_secs = local.function_defaults.timeout_secs
  mem_mb = local.function_defaults.mem_mb
  role_service_principal_ids = local.function_defaults.role_service_principal_ids
  
  lambda_details = {
    action_name = local.check_auth.details.action_name
    scope_name = var.security_scope
    policy_statements = []
  }
  depends_on = [null_resource.uploaded_objects]
}
