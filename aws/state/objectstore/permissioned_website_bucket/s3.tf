locals {
  domain_name = "${trimsuffix(var.domain_parts.controlled_domain_part, ".")}.${trimprefix(var.domain_parts.top_level_domain, ".")}"
  bucket_name = var.name
  top_level_domain = trimprefix(var.domain_parts.top_level_domain, ".")
  controlled_domain_part = trimsuffix(var.domain_parts.controlled_domain_part, ".")
}

module bucket {
  source = "../permissioned_bucket"
  name = var.name
  acl    = "public-read"
  lifecycle_rules = var.lifecycle_rules
  lambda_notifications = var.lambda_notifications
  prefix_object_permissions = var.prefix_object_permissions
  bucket_permissions = var.bucket_permissions
  principal_prefix_object_permissions = [{
    prefix = ""
    permission_type = "read_known_objects"
    principals = [var.website_access_principal]
  }]

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
