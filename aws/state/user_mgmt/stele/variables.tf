variable system_id {
  type = object({
    security_scope = string
    subsystem_name = string
  })
}

variable protected_domain_routing {
  type = object({
    domain_parts = object({
      top_level_domain = string
      controlled_domain_part = string
    })
    route53_zone_name = string
  })
}

variable aws_credentials_file {
  type = string
}

variable user_group_name {
  type = string
}

variable user_email {
  type = string
}

locals {
  protected_site_domain = "${var.protected_domain_routing.domain_parts.controlled_domain_part}.${var.protected_domain_routing.domain_parts.top_level_domain}"
  bucket_domain_parts = var.protected_domain_routing.domain_parts
  cognito_domain = "auth.${local.protected_site_domain}"
  callback_urls = [
    "https://${local.protected_site_domain}/parseauth"
  ]
  logout_urls = [
    "https://${local.protected_site_domain}/"
  ]
  allowed_oauth_scopes = ["phone", "email", "profile", "openid", "aws.cognito.signin.user.admin"]
  allowed_oauth_flows_user_pool_client = true
}
