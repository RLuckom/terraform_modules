locals {
  domain_name = "${trimsuffix(var.domain_parts.controlled_domain_part, ".")}.${trimprefix(var.domain_parts.top_level_domain, ".")}"
  bucket_name = var.name
  top_level_domain = trimprefix(var.domain_parts.top_level_domain, ".")
  controlled_domain_part = trimsuffix(var.domain_parts.controlled_domain_part, ".")
}

module bucket {
  source = "../bucket?ref=f5ba570f905b"
  name = var.name
  acl    = var.allow_direct_access ? "public-read" : "private"
  force_destroy = var.force_destroy
  lifecycle_rules = var.lifecycle_rules
  lambda_notifications = var.lambda_notifications
  prefix_object_permissions = var.prefix_object_permissions
  bucket_permissions = var.bucket_permissions
  principal_prefix_object_permissions = length(local.website_access_principals) > 0 ? [{
    prefix = ""
    permission_type = "read_known_objects"
    principals = local.website_access_principals
  }] : []

  principal_bucket_permissions = length(local.website_access_principals) > 0 ? [{
    permission_type = "list_bucket"
    principals = local.website_access_principals
  }] : []

  website_configs = [{
    index_document = "index.html"
    error_document = "error.html"
  }]

  cors_rules = [{
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = concat(["https://${local.domain_name}"], var.additional_allowed_origins)
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }]
}
