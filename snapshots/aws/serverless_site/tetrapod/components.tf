data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  system_id = var.system_id
  routing = {
    domain_parts = var.routing.domain_parts
    route53_zone_name = var.routing.route53_zone_name
    domain = "${trimsuffix(var.routing.domain_parts.controlled_domain_part, ".")}.${trimprefix(var.routing.domain_parts.top_level_domain, ".")}"
  }
  render_arn = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:site_render-${local.system_id.security_scope}"
  render_name = "site_render-${local.system_id.security_scope}"
  deletion_cleanup_arn = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:deletion_cleanup-${local.system_id.security_scope}"
  deletion_cleanup_name = "deletion_cleanup-${local.system_id.security_scope}"
  render_invoke_permission = [{
    actions   =  [
      "lambda:InvokeFunction"
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:site_render-${local.system_id.security_scope}",
    ]
  }]
}

module default_assets {
  source= "../../../themes/trails?ref=f5ba570f905b"
}

locals {
  nav_links = concat(
    var.nav_links,
    [{
      name = "Posts"
      target = "https://${local.routing.domain}/trails/posts.html"
    }]
  )
  site_description_content = var.site_description_content == "" ? templatefile(
    "${path.module}/src/site_description.json",
    {
      domain_name = local.routing.domain
      site_title = var.site_title
      maintainer = var.maintainer
      nav = {
        links = local.nav_links
      }
    }
  ) : var.site_description_content
  asset_path = var.asset_path == "" ? module.default_assets.asset_directory_root : var.asset_path
}

module asset_file_configs {
  count = var.enable ? 1 : 0
  source= "../../coordinators/asset_directory?ref=f5ba570f905b"
  asset_directory_root = local.asset_path
}

module site_static_assets {
  count = var.enable ? 1 : 0
  bucket_name = local.site_bucket
  source= "../../s3_directory?ref=f5ba570f905b"
  file_configs = module.asset_file_configs[0].file_configs
  depends_on = [module.website_bucket]
}

resource "aws_s3_bucket_object" "site_description" {
  count = var.enable ? 1 : 0
  bucket = local.site_bucket
  key    = "site_description.json"
  content_type = "application/json"
  content = local.site_description_content
  etag = md5(local.site_description_content)
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

resource "random_id" "layer_suffix" {
  byte_length = 8
}

module markdown_tools_layer {
  count = var.layers.markdown_tools.present ? 0 : 1
  source= "../../layers/markdown_tools?ref=f5ba570f905b"
  layer_name = "markdown_tools_${random_id.layer_suffix.b64_url}"
}

module donut_days_layer {
  count = var.layers.donut_days.present ? 0 : 1
  source= "../../layers/donut_days?ref=f5ba570f905b"
  layer_name = "donut_days_${random_id.layer_suffix.b64_url}"
}

locals {
  layers = {
    donut_days = var.layers.donut_days.present ? var.layers.donut_days : {
      present = true
      arn = module.donut_days_layer[0].layer.arn
    }
    markdown_tools = var.layers.markdown_tools.present ? var.layers.markdown_tools : {
      present = true 
      arn = module.markdown_tools_layer[0].layer.arn
    }
  }
}

module site_render {
  count = var.enable ? 1 : 0
  source= "../../donut_days_function?ref=b1b400e6a57a9d5"
  timeout_secs = 40
  mem_mb = 256
  log_level = var.log_level
  logging_config = local.lambda_logging_config
  config_contents = templatefile("${path.module}/src/configs/render_markdown_to_html.js",
    {
      website_bucket = local.site_bucket
      domain_name = local.routing.domain
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
  scope_name = local.system_id.security_scope
  policy_statements =  concat(
    module.trails_updater[0].permission_sets.invoke
  )
  donut_days_layer = local.layers.donut_days
  additional_layers = [
    local.layers.markdown_tools,
  ]
}

module deletion_cleanup {
  count = var.enable ? 1 : 0
  source= "../../donut_days_function?ref=b1b400e6a57a9d5"
  timeout_secs = 40
  mem_mb = 128
  logging_config = local.lambda_logging_config
  log_level =var.log_level
  config_contents = templatefile("${path.module}/src/configs/deletion_cleanup.js",
  {
    website_bucket = local.site_bucket
    domain_name = local.routing.domain
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
  scope_name = local.system_id.security_scope
  policy_statements =  concat(
    module.trails_updater[0].permission_sets.invoke
  )
  donut_days_layer = local.layers.donut_days
  additional_layers = [
    local.layers.markdown_tools,
  ]
}

module trails_updater {
  count = var.enable ? 1 : 0
  source= "../../donut_days_function?ref=b1b400e6a57a9d5"
  timeout_secs = 40
  mem_mb = 192
  logging_config = local.lambda_logging_config
  log_level = var.log_level
  config_contents = templatefile("${path.module}/src/configs/update_trails.js",
    {
      table = local.trails_table_name,
      reverse_association_index = "reverseDependencyIndex"
      domain_name = local.routing.domain
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
  scope_name = local.system_id.security_scope
  policy_statements = concat(
    local.render_invoke_permission,
  )
  donut_days_layer = local.layers.donut_days
  additional_layers = [
    local.layers.markdown_tools,
  ]
}

module trails_resolver {
  count = var.enable ? 1 : 0
  source= "../../donut_days_function?ref=b1b400e6a57a9d5"
  timeout_secs = 40
  mem_mb = 128
  logging_config = local.lambda_logging_config
  log_level =var.log_level
  config_contents = templatefile("${path.module}/src/configs/two_way_resolver.js",
  {
    table = local.trails_table_name
    forward_key_type = "trailName"
    reverse_key_type = "memberKey"
    reverse_association_index = "reverseDependencyIndex"
  })
  lambda_event_configs = var.lambda_event_configs
  action_name = "trails_resolver"
  scope_name = local.system_id.security_scope
  donut_days_layer = local.layers.donut_days
}

module site {
  count = var.enable ? 1 : 0
  source = "../../cloudfront_s3_website?ref=e976eb69c5db951b"
  website_buckets = [{
    origin_id = local.routing.domain_parts.controlled_domain_part
    regional_domain_name = "${local.site_bucket}.s3.${data.aws_region.current.name == "us-east-1" ? "" : "${data.aws_region.current.name}."}amazonaws.com"
  }]
  routing = local.routing
  system_id = local.system_id
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
  no_cache_s3_path_patterns = [ "/site_description.json" ]
  subject_alternative_names = local.subject_alternative_names
  default_cloudfront_ttls = var.default_cloudfront_ttls
}

locals {
  trails_table_delete_role_names = module.trails_updater.*.role.name
  trails_table_write_permission_role_names = module.trails_updater.*.role.name
  trails_table_read_permission_role_names = flatten([
    module.trails_resolver.*.role.name,
    module.trails_updater.*.role.name
  ])
  website_bucket_lambda_notifications = var.enable ? [
    {
      lambda_arn = module.site_render[0].lambda.arn
      lambda_name = module.site_render[0].lambda.function_name
      lambda_role_arn = module.site_render[0].role.arn
      permission_type = "put_object"
      events              = ["s3:ObjectCreated:*" ]
      filter_prefix       = ""
      filter_suffix       = ".md"
    },
    {
      lambda_arn = module.deletion_cleanup[0].lambda.arn
      lambda_name = module.deletion_cleanup[0].lambda.function_name
      lambda_role_arn = module.deletion_cleanup[0].role.arn
      permission_type = "delete_object"
      events              = ["s3:ObjectRemoved:*" ]
      filter_prefix       = ""
      filter_suffix       = ".md"
    }
  ] : []
  glue_table_permission_names = {}
  website_access_principals = local.cloudfront_origin_access_principals
}

locals {
  cloudfront_origin_access_principals = [for id in module.site.*.origin_access_identity.iam_arn : {
    type = "AWS"
    identifiers = [id]
  }]
}

module trails_table {
  source= "../../state/permissioned_dynamo_table?ref=e976eb69c5db951b"
  table_name = local.trails_table_name
  delete_item_permission_role_names = local.trails_table_delete_role_names
  write_permission_role_names = local.trails_table_write_permission_role_names
  read_permission_role_names = local.trails_table_read_permission_role_names
  partition_key = {
    name = "trailName"
    type = "S"
  }
  range_key = {
    name = "memberKey"
    type = "S"
  }
  global_indexes = [
    {
      name = "reverseDependencyIndex"
      hash_key = "memberKey"
      range_key = "trailName"
      write_capacity = 0
      read_capacity = 0
      projection_type = "ALL"
      non_key_attributes = []
    }
  ]
}

module website_bucket {
  source= "../../state/object_store/website_bucket?ref=f5ba570f905b"
  name = local.site_bucket
  force_destroy = var.force_destroy
  domain_parts = local.routing.domain_parts
  additional_allowed_origins = var.additional_allowed_origins
  website_access_principals = local.website_access_principals
  lambda_notifications = local.website_bucket_lambda_notifications
}
