locals {
  domain_name = "${trimsuffix(var.domain_parts.controlled_domain_part, ".")}.${trimprefix(var.domain_parts.top_level_domain, ".")}"
  bucket_name = var.name
  top_level_domain = trimprefix(var.domain_parts.top_level_domain, ".")
  controlled_domain_part = trimsuffix(var.domain_parts.controlled_domain_part, ".")
  cors_rules = length(var.cors_rules) == 0 && var.use_default_cors ? [{
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = concat(["https://${local.domain_name}"], var.additional_allowed_origins)
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }] : var.cors_rules
}

module bucket {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/bucket"
  name = var.name == "" ? "${var.domain_parts.controlled_domain_part}.${var.domain_parts.top_level_domain}" : var.name
  security_scope = var.security_scope
  acl    = var.allow_direct_access ? "public-read" : "private"
  force_destroy = var.force_destroy
  prefix_list_permissions = var.prefix_list_permissions
  cors_rules = local.cors_rules
  lifecycle_rules = var.lifecycle_rules
  lambda_notifications = var.lambda_notifications
  prefix_object_permissions = var.prefix_object_permissions
  bucket_permissions = var.bucket_permissions
  principal_prefix_object_permissions = length(local.website_access_principals) > 0 ? [{
    prefix = ""
    permission_type = "read_known_objects"
    principals = local.website_access_principals
  }] : []
  principal_prefix_object_denials = [for prefix in var.forbidden_website_paths : {
    prefix = prefix
    permission_type = "read_known_objects"
    principals = local.website_access_principals
  }]

  principal_bucket_permissions = length(local.website_access_principals) > 0 ? [{
    permission_type = "list_bucket"
    principals = local.website_access_principals
  }] : []

  website_configs = [{
    index_document = "index.html"
    error_document = "error.html"
  }]
}
