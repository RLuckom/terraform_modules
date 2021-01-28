data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  render_arn = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:site_render-${var.coordinator_data.scope}"
  render_name = "site_render-${var.coordinator_data.scope}"
  deletion_cleanup_arn = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:deletion_cleanup-${var.coordinator_data.scope}"
  deletion_cleanup_name = "deletion_cleanup-${var.coordinator_data.scope}"
  render_invoke_permission = [{
    actions   =  [
      "lambda:InvokeFunction"
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:site_render-${var.coordinator_data.scope}",
    ]
  }]
}

module default_assets {
  source = "github.com/RLuckom/terraform_modules//themes/trails"
}

locals {
  nav_links = concat(
    var.nav_links,
    [{
      name = "Posts"
      target = "https://${var.coordinator_data.domain}/trails/posts.html"
    }]
  )
  site_description_content = var.site_description_content == "" ? templatefile(
    "${path.module}/src/site_description.json",
    {
      domain_name = var.coordinator_data.domain
      site_title = var.site_title
      maintainer = var.maintainer
      nav = {
        links = local.nav_links
      }
    }
  ) : var.site_description_content
  asset_path = var.asset_path == "" ? module.default_assets[0].asset_directory_root : var.asset_path
}

module asset_file_configs {
  count = var.enable ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/coordinators/asset_directory"
  asset_directory_root = local.asset_path
}

module site_static_assets {
  count = var.enable ? 1 : 0
  bucket_name = var.site_bucket
  source = "github.com/RLuckom/terraform_modules//aws/s3_directory"
  file_configs = module.asset_file_configs[0].file_configs
}

resource "aws_s3_bucket_object" "site_description" {
  count = var.enable ? 1 : 0
  bucket = var.site_bucket
  key    = "site_description.json"
  content_type = "application/json"
  content = local.site_description_content
  etag = md5(local.site_description_content)
}

module archive_function {
  count = var.enable ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  timeout_secs = 15
  mem_mb = 128
  logging_config = local.lambda_logging_config
  log_level =var.log_level
  config_contents = templatefile("${path.module}/src/configs/s3_to_athena.js",
  {
    athena_region = var.coordinator_data.athena_region
    athena_db = var.coordinator_data.glue_database_name
    athena_table = var.coordinator_data.glue_table_name
    athena_catalog = "AwsDataCatalog"
    athena_result_location = var.coordinator_data.cloudfront_athena_result_location
    partition_prefix = var.coordinator_data.cloudfront_log_storage_prefix
    partition_bucket = var.coordinator_data.log_partition_bucket
  })
  lambda_event_configs = var.lambda_event_configs
  additional_helpers = [
    {
      helper_name = "athenaHelpers.js",
      file_contents = file("${path.module}/src/helpers/athenaHelpers.js")
    }
  ]
  action_name = "cloudfront_log_collector"
  scope_name = var.coordinator_data.scope
  source_bucket = var.coordinator_data.lambda_source_bucket
  donut_days_layer_arn = var.layer_arns.donut_days
}

module site_render {
  count = var.enable ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  timeout_secs = 40
  mem_mb = 256
  log_level =var.log_level
  logging_config = local.lambda_logging_config
  config_contents = templatefile("${path.module}/src/configs/render_markdown_to_html.js",
    {
      website_bucket = var.site_bucket
      domain_name = var.coordinator_data.domain
      site_description_path = "site_description.json"
      dependency_update_function = module.trails_updater[0].lambda.arn
    })
  additional_helpers = [
    {
      helper_name = "render.js"
      file_contents = file("${path.module}/src/helpers/render.js")
    },
    {
      helper_name = "idUtils.js"
      file_contents = file("${path.module}/src/helpers/idUtils.js")
    },
  ]
  lambda_event_configs = var.lambda_event_configs
  action_name = "site_render"
  scope_name = var.coordinator_data.scope
  source_bucket = var.coordinator_data.lambda_source_bucket
  policy_statements =  concat(
    module.trails_updater[0].permission_sets.invoke
  )
  donut_days_layer_arn = var.layer_arns.donut_days
  additional_layers = [
    var.layer_arns.markdown_tools,
  ]
}

module deletion_cleanup {
  count = var.enable ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  timeout_secs = 40
  mem_mb = 128
  logging_config = local.lambda_logging_config
  log_level =var.log_level
  config_contents = templatefile("${path.module}/src/configs/deletion_cleanup.js",
  {
    website_bucket = var.site_bucket
    domain_name = var.coordinator_data.domain
    site_description_path = "site_description.json"
    dependency_update_function = module.trails_updater[0].lambda.arn
  }) 
  additional_helpers = [
    {
      helper_name = "idUtils.js"
      file_contents = file("${path.module}/src/helpers/idUtils.js")
    },
  ]
  lambda_event_configs = var.lambda_event_configs
  action_name = "deletion_cleanup"
  scope_name = var.coordinator_data.scope
  source_bucket = var.lambda_bucket
  policy_statements =  concat(
    module.trails_updater[0].permission_sets.invoke
  )
  donut_days_layer_arn = var.layer_arns.donut_days
  additional_layers = [
    var.layer_arns.markdown_tools,
  ]
}

module trails_updater {
  count = var.enable ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  timeout_secs = 40
  mem_mb = 192
  logging_config = local.lambda_logging_config
  log_level =var.log_level
  config_contents = templatefile("${path.module}/src/configs/update_trails.js",
    {
      table = var.trails_table_name,
      reverse_association_index = "reverseDependencyIndex"
      domain_name = var.coordinator_data.domain
      site_description_path = "site_description.json"
      render_function = local.render_arn
      self_type = "relations.meta.trail"
    })
  additional_helpers = [
    {
      helper_name = "idUtils.js"
      file_contents = file("${path.module}/src/helpers/idUtils.js")
    },
    {
      helper_name = "trails.js"
      file_contents = file("${path.module}/src/helpers/trails.js")
    },
  ]
  lambda_event_configs = var.lambda_event_configs
  action_name = "trails_updater"
  scope_name = var.coordinator_data.scope
  source_bucket = var.lambda_bucket
  policy_statements = concat(
    local.render_invoke_permission,
  )
  donut_days_layer_arn = var.layer_arns.donut_days
  additional_layers = [
    var.layer_arns.markdown_tools,
  ]
}

module trails_resolver {
  count = var.enable ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  timeout_secs = 40
  mem_mb = 128
  logging_config = local.lambda_logging_config
  log_level =var.log_level
  config_contents = templatefile("${path.module}/src/configs/two_way_resolver.js",
  {
    table = var.trails_table_name
    forward_key_type = "trailName"
    reverse_key_type = "memberKey"
    reverse_association_index = "reverseDependencyIndex"
  })
  lambda_event_configs = var.lambda_event_configs
  action_name = "trails_resolver"
  scope_name = var.coordinator_data.scope
  source_bucket = var.lambda_bucket
  donut_days_layer_arn = var.layer_arns.donut_days
}

module site {
  count = var.enable ? 1 : 0
  source = "github.com/RLuckom/terraform_modules//aws/cloudfront_s3_website"
  website_buckets = [{
    origin_id = var.coordinator_data.domain_parts.controlled_domain_part
    regional_domain_name = "${var.site_bucket}.s3.${data.aws_region.current.name == "us-east-1" ? "" : "${data.aws_region.current.name}."}amazonaws.com"
  }]
  logging_config = local.cloudfront_logging_config
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
      arn = module.trails_resolver[0].lambda.arn
      name = module.trails_resolver[0].lambda.function_name
    }
  }]
  route53_zone_name = var.route53_zone_name
  domain_name = var.coordinator_data.domain
  no_cache_s3_path_patterns = [ "/site_description.json" ]
  controlled_domain_part = var.coordinator_data.domain_parts.controlled_domain_part
  subject_alternative_names = var.subject_alternative_names
  default_cloudfront_ttls = var.default_cloudfront_ttls
}
