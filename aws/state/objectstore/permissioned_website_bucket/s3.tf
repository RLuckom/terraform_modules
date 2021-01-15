locals {
  domain_name = "${trimsuffix(var.domain_parts.controlled_domain_part, ".")}.${trimprefix(var.domain_parts.top_level_domain, ".")}"
  bucket_name = var.bucket_name == "" ? local.domain_name : var.bucket_name
  top_level_domain = trimprefix(var.domain_parts.top_level_domain, ".")
  controlled_domain_part = trimsuffix(var.domain_parts.controlled_domain_part, ".")
}

module "bucket" {
  source = "../permissioned_bucket"
  bucket = var.bucket_name == "" ? local.domain_name : var.bucket_name
  acl    = "public-read"

  website_configs = [{
    index_document = "index.html"
    error_document = "error.html"
  }]

  cors_rules =[{
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = concat(["https://${local.domain_name}"], var.additional_allowed_origins)
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }]

  object_policy_statements = [{
    actions = ["s3:GetObject", "s3:GetObjectVersion"]
    principals = [{
      type = "*"
      identifiers = ["*"]
    }]
  }]
  lambda_notifications = var.lambda_notifications
}
