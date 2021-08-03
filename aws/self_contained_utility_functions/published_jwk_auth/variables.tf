variable account_id {
  type = string
}

variable security_scope {
  type = string
}

variable auth_config {
  type = object({
    domain = string
    dynamo_table_name = string
    dynamo_region = string
    status_code_connected = string
  })
}

variable bucket_config {
  type = object({
    supplied = bool
    credentials_file = string
    bucket = string
    prefix = string
  })
  default = {
    supplied = false
    credentials_file = ""
    bucket = ""
    prefix = ""
  }
}

locals {
  hash_suffix = substr(local.source_hash, 0, 4)
  function_defaults = {
    mem_mb = 128
    timeout_secs = 3
    role_service_principal_ids = ["edgelambda.amazonaws.com", "lambda.amazonaws.com"]
  }
  check_auth = {
    source_contents = [
      {
        file_name = "index.js"
      },
    ]
    details = {
      action_name = "check_auth_microburin"
    }
  }
}

variable unique_suffix {
  type = string
  default = ""
}

locals {
  version = "0_${local.hash_suffix}"
  rendered_index = templatefile("${path.module}/src/check_auth.js", {
    domain = var.auth_config.domain
    dynamo_region = var.auth_config.dynamo_region
    status_code_connected = var.auth_config.status_code_connected
    dynamo_table_name = var.auth_config.dynamo_table_name
  })
}

locals {
  source_hash = sha256(jsonencode({
    config = local.rendered_index
    upload = file("${path.module}/upload_populated.sh"),
    files = fileset("${path.module}/nodejs", "**")
    code = [
      local.check_auth.source_contents,
      local.function_defaults,
    ]
  }))
}
