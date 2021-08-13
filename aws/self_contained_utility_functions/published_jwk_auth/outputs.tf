output directory {
  value  = "${path.module}/nodejs"
}

output function_configs {
  value = {
    function_defaults = local.function_defaults
    check_auth = local.check_auth
  }
}

output s3_objects {
  value = {
    check_auth = {
      supplied = true
      bucket = var.bucket_config.bucket
      path = trimprefix("${trimsuffix(var.bucket_config.prefix, "/")}/check_auth_${local.version}.zip", "/")
    }
  }
}

output role {
  value = module.check_auth.role
}

output access_control_function_qualified_arns {
  value = {
    check_auth   = module.check_auth.qualified_arn
    refresh_auth   = ""
    parse_auth   = ""
    sign_out   = ""
    http_headers = ""
    move_cookie_to_auth_header = ""
  }
}
