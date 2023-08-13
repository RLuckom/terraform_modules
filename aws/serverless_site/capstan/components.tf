locals {
  system_id = var.coordinator_data.system_id
  routing = var.coordinator_data.routing
}

module site_static_assets {
  count = length(var.asset_paths)
  source = "github.com/RLuckom/terraform_modules//aws/local_directory_to_s3"
  bucket_name = module.website_bucket.bucket_name
  asset_directory_root = var.asset_paths[count.index].local_path
  s3_asset_prefix = var.asset_paths[count.index].s3_prefix
  depends_on = [module.website_bucket]
}

resource "aws_s3_object" "assets" {
  count = length(var.file_configs)
  bucket = module.website_bucket.bucket_name
  key    = var.file_configs[count.index].key
  acl    = var.file_configs[count.index].acl
  content_type = var.file_configs[count.index].content_type
  content = var.file_configs[count.index].file_contents
  source = var.file_configs[count.index].file_contents != null ? null : var.file_configs[count.index].file_path
}

resource "aws_s3_object" "ignore_changes_assets" {
  count = length(var.ignore_changes_file_configs)
  bucket = module.website_bucket.bucket_name
  key    = var.ignore_changes_file_configs[count.index].key
  acl    = var.ignore_changes_file_configs[count.index].acl
  content_type = var.ignore_changes_file_configs[count.index].content_type
  content = var.ignore_changes_file_configs[count.index].file_contents
  source = var.ignore_changes_file_configs[count.index].file_contents != null ? null : var.ignore_changes_file_configs[count.index].file_path
  lifecycle {
    ignore_changes = [content, source, content_type]
  }
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
  unique_suffix = var.unique_suffix
  enable_distribution = var.enable
  access_control_function_qualified_arns = var.access_control_function_qualified_arns
  access_control_function_include_body = var.access_control_function_include_body
  no_access_control_s3_path_patterns = var.no_access_control_s3_path_patterns
  website_buckets = [{
    origin_id = local.routing.domain_parts.controlled_domain_part
    regional_domain_name = "${module.website_bucket.bucket_name}.s3.${var.region == "us-east-1" ? "" : "${var.region}."}amazonaws.com"
  }]
  routing = local.routing
  system_id = local.system_id
  logging_config = local.cloudfront_logging_config
  lambda_authorizers = var.lambda_authorizers
  lambda_origins = var.lambda_origins 
  no_cache_s3_path_patterns = var.no_cache_s3_path_patterns
  preemptive_s3_path_patterns = var.preemptive_s3_path_patterns
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
  unique_suffix = var.unique_suffix
  name = local.site_bucket
  need_policy_override = var.need_website_bucket_policy_override
  account_id = var.account_id
  region = var.region
  force_destroy = var.force_destroy
  security_scope = var.coordinator_data.system_id.security_scope
  domain_parts = local.routing.domain_parts
  cors_rules = var.website_bucket_cors_rules
  forbidden_website_paths = var.forbidden_website_paths
  additional_allowed_origins = var.additional_allowed_origins
  prefix_object_permissions = var.website_bucket_prefix_object_permissions
  prefix_list_permissions = var.website_bucket_prefix_list_permissions
  bucket_permissions = var.website_bucket_bucket_permissions
  website_access_principals = local.website_access_principals
  lambda_notifications = local.website_bucket_lambda_notifications
}
