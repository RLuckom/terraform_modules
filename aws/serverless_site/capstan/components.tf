data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  system_id = var.coordinator_data.system_id
  routing = var.coordinator_data.routing
}

module site_static_assets {
  count = length(var.asset_paths)
  source = "github.com/RLuckom/terraform_modules//aws/local_directory_to_s3"
  bucket_name = local.site_bucket
  asset_directory_root = var.asset_paths[count.index].local_path
  s3_asset_prefix = var.asset_paths[count.index].s3_prefix
  depends_on = [module.website_bucket]
}

resource "aws_s3_bucket_object" "assets" {
  count = length(var.file_configs)
  bucket = local.site_bucket
  key    = var.file_configs[count.index].key
  content_type = var.file_configs[count.index].content_type
  content = var.file_configs[count.index].file_contents
  source = var.file_configs[count.index].file_contents != null ? null : var.file_configs[count.index].file_path
}

locals {
  cloudfront_delivery_prefixes = [
    var.coordinator_data.cloudfront_log_delivery_prefix
  ]
  log_destination_prefixes = [
    var.coordinator_data.cloudfront_log_delivery_prefix
  ]
}

module site {
  source = "github.com/RLuckom/terraform_modules//aws/cloudfront_s3_website"
  enable_distribution = var.enable
  access_control_function_qualified_arns = var.access_control_function_qualified_arns
  website_buckets = [{
    origin_id = local.routing.domain_parts.controlled_domain_part
    regional_domain_name = "${local.site_bucket}.s3.${data.aws_region.current.name == "us-east-1" ? "" : "${data.aws_region.current.name}."}amazonaws.com"
  }]
  routing = local.routing
  system_id = local.system_id
  logging_config = local.cloudfront_logging_config
  lambda_authorizers = var.lambda_authorizers
  lambda_origins = var.lambda_origins 
  no_cache_s3_path_patterns = var.no_cache_s3_path_patterns
  subject_alternative_names = local.subject_alternative_names
  default_cloudfront_ttls = var.default_cloudfront_ttls
}

locals {
  website_bucket_lambda_notifications = var.enable ? var.website_bucket_lambda_notifications : []
  glue_table_permission_names = {}
  website_access_principals = local.cloudfront_origin_access_principals
}

locals {
  cloudfront_origin_access_principals = [for id in module.site.*.origin_access_identity.iam_arn : {
    type = "AWS"
    identifiers = [id]
  }]
}

module website_bucket {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/website_bucket"
  name = local.site_bucket
  force_destroy = var.force_destroy
  security_scope = var.coordinator_data.system_id.security_scope
  domain_parts = local.routing.domain_parts
  cors_rules = var.website_bucket_cors_rules
  forbidden_website_paths = var.forbidden_website_paths
  additional_allowed_origins = var.additional_allowed_origins
  prefix_object_permissions = var.website_bucket_prefix_object_permissions
  bucket_permissions = var.website_bucket_bucket_permissions
  website_access_principals = local.website_access_principals
  lambda_notifications = local.website_bucket_lambda_notifications
}
