data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  system_id = var.system_id
  routing = {
    domain_parts = var.routing.domain_parts
    route53_zone_name = var.routing.route53_zone_name
    domain = "${trimsuffix(var.routing.domain_parts.controlled_domain_part, ".")}.${trimprefix(var.routing.domain_parts.top_level_domain, ".")}"
  }
}

module site_static_assets {
  count = var.asset_path == "" ? 0 : 1
  source = "github.com/RLuckom/terraform_modules//aws/local_directory_to_s3"
  bucket_name = local.site_bucket
  asset_directory_root = var.asset_path
  depends_on = [module.website_bucket]
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
  domain_parts = local.routing.domain_parts
  additional_allowed_origins = var.additional_allowed_origins
  prefix_object_permissions = var.website_bucket_prefix_object_permissions
  website_access_principals = local.website_access_principals
  lambda_notifications = local.website_bucket_lambda_notifications
}
