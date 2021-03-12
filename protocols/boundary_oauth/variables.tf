variable token_issuer {
  type = string
}

variable client_id {
  type = string
}

variable client_secret {
  type = string
}

variable nonce_signing_secret {
  type = string
}

variable auth_domain {
  type = string
}

variable user_group_name {
  type = string
}

variable log_source {
  type = string
  default = ""
}

variable log_source_instance {
  type = string
  default = ""
}

//TODO set each config separately, make the fn names the component?
variable component {
  type = string
  default = ""
}

variable log_level {
  type = string
  default = "ERROR"
}

variable http_header_values {
  type = map(string)
  default = {
    "Content-Security-Policy" = "default-src 'self'"
    "Strict-Transport-Security" = "max-age=31536000; includeSubdomains; preload"
    "Referrer-Policy" = "same-origin"
    "X-XSS-Protection" = "1; mode=block"
    "X-Frame-Options" = "DENY"
    "X-Content-Type-Options" = "nosniff"
  }
}

locals {
  http_header_values = var.http_header_values
  set_headers_config = {
    httpHeaders = local.http_header_values
    logLevel = var.log_level
  }
  full_config_json = {
    source = var.log_source
    sourceInstance = var.log_source_instance
    component = var.component
    tokenIssuer = var.token_issuer
    tokenJwksUri = "${var.token_issuer}/.well-known/jwks.json"
    clientId = var.client_id
    clientSecret = var.client_secret
    oauthScopes = ["phone", "email", "profile", "openid", "aws.cognito.signin.user.admin"]
    authDomain = var.auth_domain
    redirectPathSignIn = "/parseauth"
    redirectPathSignOut = "/"
    redirectPathAuthRefresh = "/refreshauth"
    cookieSettings = {
      idToken = null
      accessToken = null
      refreshToken = null
      nonce = null
    }
    httpHeaders = local.http_header_values
    logLevel = var.log_level
    nonceSigningSecret = var.nonce_signing_secret
    additionalCookies = {}
    requiredGroup = var.user_group_name
  }
  function_defaults = {
    mem_mb = 128
    timeout_secs = 3
    shared_source = [
      {
        file_name = "shared/shared.js"
        file_contents = file("${path.module}/src/shared/shared.js")
      },
      {
        file_name = "shared/validate_jwt.js"
        file_contents = file("${path.module}/src/shared/validate_jwt.js")
      },
      {
        file_name = "shared/error_page/template.html"
        file_contents = file("${path.module}/src/shared/error_page/template.html")
      }
    ]
    role_service_principal_ids = ["edgelambda.amazonaws.com", "lambda.amazonaws.com"]
  }
  http_headers = {
    source_contents = concat(local.function_defaults.shared_source, [
      {
        file_name = "index.js"
        file_contents = file("${path.module}/src/http_headers.js")
      },
      {
        file_name = "config.json"
        file_contents = jsonencode(local.set_headers_config)
      }
    ])
    details = {
      action_name = "http_headers"
    }
  }
  check_auth = {
    source_contents = concat(local.function_defaults.shared_source, [
      {
        file_name = "index.js"
        file_contents = file("${path.module}/src/check_auth.js")
      },
      {
        file_name = "config.json"
        file_contents = jsonencode(local.full_config_json)
      }
    ])
    details = {
      action_name = "check_auth"
    }
  }
  sign_out = {
    source_contents = concat(local.function_defaults.shared_source, [
      {
        file_name = "index.js"
        file_contents = file("${path.module}/src/sign_out.js")
      },
      {
        file_name = "config.json"
        file_contents = jsonencode(local.full_config_json)
      }
    ])
    details = {
      action_name = "sign_out"
    }
  }
  refresh_auth = {
    source_contents = concat(local.function_defaults.shared_source, [
      {
        file_name = "index.js"
        file_contents = file("${path.module}/src/refresh_auth.js")
      },
      {
        file_name = "config.json"
        file_contents = jsonencode(local.full_config_json)
      }
    ])
    details = {
      action_name = "refresh_auth"
    }
  }
  parse_auth = {
    source_contents = concat(local.function_defaults.shared_source, [
      {
        file_name = "index.js"
        file_contents = file("${path.module}/src/parse_auth.js")
      },
      {
        file_name = "config.json"
        file_contents = jsonencode(local.full_config_json)
      }
    ])
    details = {
      action_name = "parse_auth"
    }
  }
}

output directory {
  value  = "${path.module}/nodejs"
}

output function_configs {
  value = {
    function_defaults = local.function_defaults
    http_headers = local.http_headers
    parse_auth = local.parse_auth
    check_auth = local.check_auth
    refresh_auth = local.refresh_auth
    sign_out = local.sign_out
  }
}
