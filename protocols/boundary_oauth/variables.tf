variable token_issuer {
  type = string
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

variable sign_out_path {
  type = string
  default = "/"
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
    redirectPathSignOut = var.sign_out_path
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
  hash_suffix = substr(sha256(jsonencode(local.full_config_json)), 0, 4)
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
  move_cookie_to_auth_header = {
    source_contents = concat(local.function_defaults.shared_source, [
      {
        file_name = "index.js"
        file_contents = file("${path.module}/src/move_cookie.js")
      },
    ])
    details = {
      action_name = "move_cookie"
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
    move_cookie_to_auth_header = local.move_cookie_to_auth_header
    refresh_auth = local.refresh_auth
    sign_out = local.sign_out
  }
}

output s3_objects {
  value = {
    http_headers = {
      supplied = true
      bucket = var.bucket_config.bucket
      path = trimprefix("${var.bucket_config.prefix}/http_headers_${local.version}.zip", "/")
    }
    parse_auth = {
      supplied = true
      bucket = var.bucket_config.bucket
      path = trimprefix("${var.bucket_config.prefix}/parse_auth_${local.version}.zip", "/")
    }
    check_auth = {
      supplied = true
      bucket = var.bucket_config.bucket
      path = trimprefix("${var.bucket_config.prefix}/check_auth_${local.version}.zip", "/")
    }
    move_cookie_to_auth_header = {
      supplied = true
      bucket = var.bucket_config.bucket
      path = trimprefix("${var.bucket_config.prefix}/move_cookie_${local.version}.zip", "/")
    }
    refresh_auth = {
      supplied = true
      bucket = var.bucket_config.bucket
      path = trimprefix("${var.bucket_config.prefix}/refresh_auth_${local.version}.zip", "/")
    }
    sign_out = {
      supplied = true
      bucket = var.bucket_config.bucket
      path = trimprefix("${var.bucket_config.prefix}/sign_out_${local.version}.zip", "/")
    }
  }
}

locals {
  version = "0_${local.hash_suffix}"
}

resource null_resource uploaded_objects {
  count = var.bucket_config.supplied ? 1 : 0
  triggers = {
    config = jsonencode(local.full_config_json)
    version = local.version
  }

  provisioner "local-exec" {
    command = templatefile("${path.module}/upload_populated.sh",
    {
      // CSP headers include single-quotes, this shepherds them through bash
      full_config = replace(jsonencode(local.full_config_json), "'", "'\"'\"'")
      headers_config = replace(jsonencode(local.set_headers_config), "'", "'\"'\"'")
      bucket = var.bucket_config.bucket
      prefix = var.bucket_config.prefix
      version = local.version
    })
    environment = {
      AWS_SHARED_CREDENTIALS_FILE = var.bucket_config.credentials_file
    }
    working_dir = path.module
  }
}

output config_hash {
  value = sha256(jsonencode(local.full_config_json))
}
