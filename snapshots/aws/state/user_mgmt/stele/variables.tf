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
    domain = string
  })
}

variable user_group_name {
  type = string
}

variable user_email {
  type = string
}

variable aws_credentials_file {
  type = string
  default = "/.aws/credentials"
}

variable additional_protected_domains {
  type = list(string)
  default = []
}

locals {
  protected_site_domain = var.protected_domain_routing.domain
  bucket_domain_parts = var.protected_domain_routing.domain_parts
  cognito_domain = "auth.${local.protected_site_domain}"
  callback_urls = concat([
    "https://${local.protected_site_domain}/parseauth"
  ], [for domain in var.additional_protected_domains : "https://${domain}/parseauth"] )
  logout_urls = concat([
    "https://${local.protected_site_domain}/"
  ], [for domain in var.additional_protected_domains : "https://${domain}/"] )
  allowed_oauth_scopes = ["phone", "email", "profile", "openid", "aws.cognito.signin.user.admin"]
  allowed_oauth_flows_user_pool_client = true
}
