variable security_scope {
  type = string
}

variable account_id {
  type = string
}

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

variable protected_domain_routing {
  type = object({
    domain_parts = object({
      top_level_domain = string
      controlled_domain_part = string
    })
    domain = string
    route53_zone_name = string
  })
}

locals {
  protected_site_domain = var.protected_domain_routing.domain
  auth_domain = "https://${var.auth_domain_prefix}.${local.protected_site_domain}"
}

variable user_group_name {
  type = string
}

variable auth_domain_prefix {
  type = string
  default = "auth"
}

variable aws_credentials_file {
  type = string
  default = "/.aws/credentials"
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

variable plugin_root {
  type = string
  default = "/plugins/"
}

variable http_header_values_by_plugin {
  type = map(map(string))
  default = {}
}
