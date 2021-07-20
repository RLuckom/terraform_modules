locals {
  system_id = var.coordinator_data.system_id
  routing = var.coordinator_data.routing
  render_arn = "arn:aws:lambda:${var.region}:${var.account_id}:function:site_render-${local.system_id.security_scope}"
  render_name = "site_render-${local.system_id.security_scope}"
  deletion_cleanup_arn = "arn:aws:lambda:${var.region}:${var.account_id}:function:deletion_cleanup-${local.system_id.security_scope}"
  deletion_cleanup_name = "deletion_cleanup-${local.system_id.security_scope}"
  render_invoke_permission = [{
    actions   =  [
      "lambda:InvokeFunction"
    ]
    resources = [
      "arn:aws:lambda:${var.region}:${var.account_id}:function:site_render-${local.system_id.security_scope}",
    ]
  }]
}

locals {
  nav_links = jsonencode(concat(
    var.nav_links,
    [{
      name = "Posts"
      target = "https://${local.routing.domain}/trails/posts.html"
    }]
  ))
  render_config = templatefile(
    "${path.module}/src/render_config.js",
    {
      domain_name = local.routing.domain
      site_title = var.site_title
      nav_links = local.nav_links
      aws_region = var.region
      table_name = module.trails_table.table_name
      post_template_key = "assets/templates/post.tmpl"
      trail_template_key = "assets/templates/trail.tmpl"
    }
  )
  default_asset_file_configs = [
    {
      content_type = "text/plain; charset=utf-8"
      key = "/assets/templates/trail.tmpl"
      file_path = "${path.module}/default_assets/templates/trail.tmpl",
    },
    {
      content_type = "text/plain; charset=utf-8"
      key = "/assets/templates/post.tmpl"
      file_path = "${path.module}/default_assets/templates/post.tmpl"
    },
    {
      content_type = "text/css; charset=utf-8"
      key = "/assets/css/main.css"
      file_path = "${path.module}/default_assets/css/main.css"
    },
    {
      content_type = "text/css; charset=utf-8"
      key = "/assets/css/highlight.css"
      file_path = "${path.module}/default_assets/css/highlight.css"
    },
  ]
}

module site_static_assets {
  source = "github.com/RLuckom/terraform_modules//aws/s3_directory"
  bucket_name = module.website_bucket.bucket_name
  file_configs = var.asset_file_configs == null ? local.default_asset_file_configs : var.asset_file_configs 
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
  source = "github.com/RLuckom/terraform_modules//aws/layers/markdown_tools"
  layer_name = "markdown_tools_${random_id.layer_suffix.b64_url}"
}

module donut_days_layer {
  count = var.layers.donut_days.present ? 0 : 1
  source = "github.com/RLuckom/terraform_modules//aws/layers/donut_days"
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
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  unique_suffix = var.unique_suffix
  timeout_secs = 40
  mem_mb = 256
  account_id = var.account_id
  region = var.region
  log_level = var.log_level
  logging_config = local.lambda_logging_config
  config_contents = local.render_config
  additional_helpers = [
    {
      helper_name = "render_utils.js"
      file_contents = file("${path.module}/src/render_utils.js")
    },
  ]
  lambda_event_configs = var.lambda_event_configs
  action_name = "site_render"
  scope_name = local.system_id.security_scope
  donut_days_layer = local.layers.donut_days
  additional_layers = [
    local.layers.markdown_tools,
  ]
}

module site {
  source = "github.com/RLuckom/terraform_modules//aws/cloudfront_s3_website"
  unique_suffix = var.unique_suffix
  enable_distribution = var.enable
  access_control_function_qualified_arns = var.access_control_function_qualified_arns
  website_buckets = [{
    origin_id = local.routing.domain_parts.controlled_domain_part
    regional_domain_name = "${module.website_bucket.bucket_name}.s3.${var.region == "us-east-1" ? "" : "${var.region}."}amazonaws.com"
  }]
  routing = local.routing
  system_id = local.system_id
  logging_config = local.cloudfront_logging_config
  lambda_authorizers = var.lambda_authorizer.name == "NONE" ? {} : map(var.lambda_authorizer.name, var.lambda_authorizer)
  subject_alternative_names = local.subject_alternative_names
  default_cloudfront_ttls = var.default_cloudfront_ttls
}

locals {
  trails_table_delete_role_names = [module.site_render.role.name]
  trails_table_write_permission_role_names = [module.site_render.role.name]
  trails_table_read_permission_role_names = [
      module.site_render.role.name,
  ]
  website_bucket_lambda_notifications = [
    {
      lambda_arn = module.site_render.lambda.arn
      lambda_name = module.site_render.lambda.function_name
      lambda_role_arn = module.site_render.role.arn
      permission_type = "read_and_tag_known"
      events              = ["s3:ObjectCreated:*" ]
      filter_prefix       = ""
      filter_suffix       = ".md"
    },
    {
      lambda_arn = module.site_render.lambda.arn
      lambda_name = module.site_render.lambda.function_name
      lambda_role_arn = module.site_render.role.arn
      permission_type = "read_and_tag_known"
      events              = ["s3:ObjectRemoved:*" ]
      filter_prefix       = ""
      filter_suffix       = ".md"
    }
  ]
  website_bucket_suffix_object_denials = concat(var.website_bucket_suffix_object_denials, [{
    permission_type = "put_object"
    suffix = ".md"
    arns = [
      module.site_render.role.arn
    ]
  }])
  glue_table_permission_names = {}
  website_access_principals = local.cloudfront_origin_access_principals
}

locals {
  cloudfront_origin_access_principals = [{
    type = "AWS"
    identifiers = [module.site.origin_access_identity.iam_arn]
  }]
}

module trails_table {
  source = "github.com/RLuckom/terraform_modules//aws/state/permissioned_dynamo_table"
  account_id = var.account_id
  region = var.region
  unique_suffix = var.unique_suffix
  table_name = local.trails_table_name
  delete_item_permission_role_names = local.trails_table_delete_role_names
  write_permission_role_names = local.trails_table_write_permission_role_names
  read_permission_role_names = local.trails_table_read_permission_role_names
  partition_key = {
    name = "kind"
    type = "S"
  }
  range_key = {
    name = "id"
    type = "S"
  }
}

module website_bucket {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/website_bucket"
  unique_suffix = var.unique_suffix
  name = local.site_bucket
  account_id = var.account_id
  region = var.region
  force_destroy = var.force_destroy
  domain_parts = local.routing.domain_parts
  cors_rules = var.website_bucket_cors_rules
  prefix_object_permissions = concat(
    [
      {
        permission_type = "read_known_objects",
        prefix = "templates"
        arns = [
          module.site_render.role.arn
        ]
      },
      {
        permission_type = "read_write_objects",
        prefix = ""
        arns = [
          module.site_render.role.arn
        ]
      },
      {
        permission_type = "delete_object",
        prefix = ""
        arns = [
          module.site_render.role.arn
        ]
      },
    ],
    var.website_bucket_prefix_object_permissions
  )
  suffix_object_denials = local.website_bucket_suffix_object_denials
  forbidden_website_paths = concat(["assets/templates"], var.forbidden_website_paths)
  bucket_permissions = concat(
    [],
    var.website_bucket_bucket_permissions
  )
  additional_allowed_origins = var.additional_allowed_origins
  website_access_principals = local.website_access_principals
  lambda_notifications = local.website_bucket_lambda_notifications
}
