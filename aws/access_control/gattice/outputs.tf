output move_cookie_to_auth_header {
  value = module.move_cookie_to_auth_header
}

output sign_out {
  value = module.sign_out
}

output http_headers {
  value = module.http_headers
}

output check_auth {
  value = module.check_auth
}

output refresh_auth {
  value = module.refresh_auth
}

output parse_auth {
  value = module.parse_auth
}

output access_control_function_qualified_arns {
  value = {
    refresh_auth   = module.refresh_auth.qualified_arn
    parse_auth   = module.parse_auth.qualified_arn
    check_auth   = module.check_auth.qualified_arn
    sign_out   = module.sign_out.qualified_arn
    http_headers   = module.http_headers.qualified_arn
    move_cookie_to_auth_header   = module.move_cookie_to_auth_header.qualified_arn
  }
}
