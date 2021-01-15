data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  domain_name = "${trimsuffix(var.domain_parts.controlled_domain_part, ".")}.${trimprefix(var.domain_parts.top_level_domain, ".")}"
  controlled_domain_part = trimsuffix(var.domain_parts.controlled_domain_part, ".")
  render_arn = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:site_render-${var.purpose_descriptor}"
  render_name = "site_render-${var.purpose_descriptor}"
  deletion_cleanup_arn = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:deletion_cleanup-${var.purpose_descriptor}"
  deletion_cleanup_name = "deletion_cleanup-${var.purpose_descriptor}"
  render_invoke_permission = [{
    actions   =  [
      "lambda:InvokeFunction"
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:site_render-${var.purpose_descriptor}",
    ]
  }]
}

module "site_render" {
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  timeout_secs = 40
  mem_mb = 256
  debug = var.debug
  config_contents = templatefile("${path.root}/functions/configs/render_markdown_to_html/config.js",
    {
      website_bucket = var.site_bucket
      domain_name = local.domain_name
      site_description_path = "site_description.json"
      dependency_update_function = module.trails_updater.lambda.arn
    })
  additional_helpers = [
    {
      helper_name = "render.js"
      file_contents = file("${path.root}/functions/libraries/src/helpers/render.js")
    },
    {
      helper_name = "idUtils.js"
      file_contents = file("${path.root}/functions/libraries/src/helpers/idUtils.js")
    },
  ]
  lambda_event_configs = var.lambda_event_configs
  action_name = "site_render"
  scope_name = var.purpose_descriptor
  source_bucket = var.lambda_bucket
  policy_statements =  concat(
    module.trails_updater.permission_sets.invoke
  )
  donut_days_layer_arn = var.layer_arns.donut_days
  additional_layers = [
    var.layer_arns.markdown_tools,
  ]
}

module "deletion_cleanup" {
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  timeout_secs = 40
  mem_mb = 128
  debug = var.debug
  log_bucket = var.lambda_logging_bucket
  config_contents = templatefile("${path.root}/functions/configs/deletion_cleanup/config.js",
  {
    website_bucket = var.site_bucket
    domain_name = local.domain_name
    site_description_path = "site_description.json"
    dependency_update_function = module.trails_updater.lambda.arn
  }) 
  additional_helpers = [
    {
      helper_name = "idUtils.js"
      file_contents = file("${path.root}/functions/libraries/src/helpers/idUtils.js")
    },
  ]
  lambda_event_configs = var.lambda_event_configs
  action_name = "deletion_cleanup"
  scope_name = var.purpose_descriptor
  source_bucket = var.lambda_bucket
  policy_statements =  concat(
    module.trails_updater.permission_sets.invoke
  )
  donut_days_layer_arn = var.layer_arns.donut_days
  additional_layers = [
    var.layer_arns.markdown_tools,
  ]
}

module "trails_updater" {
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  timeout_secs = 40
  mem_mb = 192
  debug = var.debug
  log_bucket = var.lambda_logging_bucket
  config_contents = templatefile("${path.root}/functions/configs/update_trails/config.js",
    {
      table = var.trails_table.name,
      reverse_association_index = "reverseDependencyIndex"
      domain_name = local.domain_name
      site_description_path = "site_description.json"
      render_function = local.render_arn
      self_type = "relations.meta.trail"
    })
  additional_helpers = [
    {
      helper_name = "idUtils.js"
      file_contents = file("${path.root}/functions/libraries/src/helpers/idUtils.js")
    },
    {
      helper_name = "trails.js"
      file_contents = file("${path.root}/functions/libraries/src/trails.js")
    },
  ]
  lambda_event_configs = var.lambda_event_configs
  action_name = "trails_updater"
  scope_name = var.purpose_descriptor
  source_bucket = var.lambda_bucket
  policy_statements = concat(
    local.render_invoke_permission,
    var.trails_table.permission_sets.read,
    var.trails_table.permission_sets.write,
    var.trails_table.permission_sets.delete_item,
  )
  donut_days_layer_arn = var.layer_arns.donut_days
  additional_layers = [
    var.layer_arns.markdown_tools,
  ]
}

module "site" {
  source = "github.com/RLuckom/terraform_modules//aws/cloudfront_s3_website"
  website_buckets = [{
    origin_id = local.controlled_domain_part
    regional_domain_name = "${var.site_bucket}.s3.${data.aws_region.current.name == "us-east-1" ? "" : "${data.aws_region.current.name}."}amazonaws.com"
  }]
  logging_config = {
    bucket_id = var.site_logging_bucket
    include_cookies = var.include_cookies_in_logging
  }
  lambda_origins = [{
    id = "trails"
    path = "/meta/relations/trails"
    site_path = "/meta/relations/trails*"
    apigateway_path = "/meta/relations/trails/{trail+}"
    gateway_name_stem = "trails"
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD"]
    compress = true
    ttls = {
      min = 0
      default = 0
      max = 0
    }
    forwarded_values = {
      query_string = true
      query_string_cache_keys = []
      headers = []
    }
    lambda = {
      arn = module.trails_resolver.lambda.arn
      name = module.trails_resolver.lambda.function_name
    }
  }]
  route53_zone_name = var.route53_zone_name
  domain_name = local.domain_name
  no_cache_s3_path_patterns = [ "/site_description.json" ]
  domain_name_prefix = local.controlled_domain_part
  subject_alternative_names = var.subject_alternative_names
  default_cloudfront_ttls = var.default_cloudfront_ttls
}

resource "aws_s3_bucket_object" "site_description" {
  bucket = var.site_bucket
  key    = "site_description.json"
  content_type = "application/json"
  content = var.site_description_content
  etag = md5(var.site_description_content)
}

module "trails_resolver" {
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  timeout_secs = 40
  mem_mb = 128
  debug = var.debug
  log_bucket = var.lambda_logging_bucket
  config_contents = templatefile("${path.root}/functions/configs/two_way_resolver/config.js",
  {
    table = var.trails_table.name
    forward_key_type = "trailName"
    reverse_key_type = "memberKey"
    reverse_association_index = "reverseDependencyIndex"
  })
  lambda_event_configs = var.lambda_event_configs
  action_name = "trails_resolver"
  scope_name = var.purpose_descriptor
  policy_statements = concat(
    var.trails_table.permission_sets.read,
  )
  source_bucket = var.lambda_bucket
  donut_days_layer_arn = var.layer_arns.donut_days
}
