variable name {
  type = string
}

variable region {
  type = string
}

variable account_id {
  type = string
}

variable gopher_config_content {
  type = string
}

variable admin_site_resources {
  type = object({
    default_styles_path = string
    default_scripts_path = string
    header_contents = string
    footer_contents = string
    lodash_path = string
    exploranda_path = string
    aws_path = string
    site_title = string
    site_description = string
  })
  default = {
    default_styles_path = ""
    default_scripts_path = ""
    lodash_path = ""
    aws_path = ""
    exploranda_path = ""
    header_contents = "<div class=\"header-block\"><h1 class=\"heading\">Private Site</h1></div>"
    footer_contents = "<div class=\"footer-block\"><h1 class=\"footing\">Private Site</h1></div>"
    site_title = "running_material.site_title"
    site_description = "running_material.site_description"
  }
}

variable plugin_config {
  type = object({
    domain = string
    bucket_name = string
    upload_root = string
    api_root = string
    aws_credentials_endpoint = string
    hosting_root = string
    source_root = string
    authenticated_role = object({
      arn = string
      name = string
    })
  })
}

variable coordinator_data {
  type = object({
    system_id = object({
      security_scope = string
      subsystem_name = string
    })
    routing = object({
      domain_parts = object({
        top_level_domain = string
        controlled_domain_part = string
      })
      domain = string
      route53_zone_name = string
    })
    // these can be set to "" if NA
    metric_table = string
    lambda_log_delivery_prefix = string
    lambda_log_delivery_bucket = string
    cloudfront_log_delivery_prefix = string
    cloudfront_log_delivery_bucket = string
  })
}

variable library_const_names {
  type = list(string)
  default = []
}

variable config_values {
  type = map(string)
  default = {}
}

variable default_css_paths {
  type = list(string)
  default = []
}

variable default_script_paths {
  type = list(string)
  default = []
}

variable default_deferred_script_paths {
  type = list(string)
  default = []
}

variable page_configs {
  type = map(object({
    css_paths = list(string)
    script_paths = list(string)
    deferred_script_paths = list(string)
    render_config_path = string
  }))
  default = {}
}

variable plugin_file_configs {
  type = list(object({
    content_type = string
    key = string
    file_path = string
    file_contents = string
  }))
  default = []
}

output libaries {
  value = local.libraries
}

locals {
  libaries = {
    aws = var.admin_site_resources.aws_script_path,
    lodash = var.admin_site_resources.lodash_path,
    exploranda = var.admin_site_resources.exploranda_path,
  }
  file_prefix = trim(var.plugin_config.source_root, "/")
  config_path = "${local.file_prefix}/assets/js/config.js"
  utils_js_path = "${local.file_prefix}/assets/js/utils-${filemd5("${path.module}/src/frontend/libs/utils.js")}.js"
  gopher_config_js_path = "${local.file_prefix}/assets/js/gopher_config-${filemd5("${path.module}/src/frontend/libs/gopher_config.js")}.js"

  plugin_config = merge({
    name = var.name
    domain = var.plugin_config.domain
    private_storage_bucket = var.plugin_config.bucket_name
    upload_root = "${trimsuffix(var.plugin_config.upload_root, "/")}/"
    aws_credentials_endpoint = var.plugin_config.aws_credentials_endpoint
    plugin_root = "${trimsuffix(var.plugin_config.source_root, "/")}/"
    api_root = "${trimsuffix(var.plugin_config.api_root, "/")}/"
    hosting_root = "${trimsuffix(var.plugin_config.hosting_root, "/")}/"
  }, var.config_values)
  default_css_paths = concat(var.default_css_paths, [
    var.admin_site_resources.default_styles_path,
  ])
  default_deferred_script_paths = concat(var.default_deferred_script_paths, [
    var.admin_site_resources.default_scripts_path,
  ])
  default_script_paths = concat(var.default_script_paths, [
    local.config_path,
    local.gopher_config_js_path,
    local.utils_js_path,
  ])
  index_script_paths = [
    local.index_js_path
  ]
  files = flatten([
    [for page_name, page_config in var.page_configs : {
      key = "${local.file_prefix}${page_name}.html"
      file_contents = templatefile("${path.module}/src/frontend/index.html", {
      running_material = var.admin_site_resources
      css_paths = concat(
        local.default_css_paths,
        page_config.css_paths
      )
      script_paths = concat(
        local.default_script_paths,
        ["${local.file_prefix}${page_name}.js"],
        page_config.script_paths
      )
      deferred_script_paths = concat(
        local.default_deferred_script_paths,
        page_config.deferred_script_paths
      )
    })
      content_type = "text/html"
      file_path = ""
    }],
    [for page_name, page_config in var.page_configs : {
      key = "${local.file_prefix}${page_name}.js"
      file_contents = null
      file_path = page_config.render_config_path
      content_type = "application/javascript"
      file_path = ""
    }],
    var.plugin_file_configs,
    {
      key = local.config_path
      file_contents = <<EOF
window.CONFIG = ${jsonencode(local.plugin_config)}
const {${join(", ", var.library_const_names)}} = window.LIBRARIES
EOF
      file_path = null
      content_type = "application/javascript"
    },
    {
      key = "${local.file_prefix}/assets/js/gopher_config-${md5(var.gopher_config_content)}.js"
      file_contents = var.gopher_config_content
      file_path = null
      content_type = "application/javascript"
    },
    {
      key = local.utils_js_path
      file_contents = null
      file_path = "${path.module}/src/frontend/libs/utils.js"
      content_type = "application/javascript"
    },
  ])
}

output files {
  value = [ for conf in local.files : {
    plugin_relative_key = replace(conf.key, local.file_prefix, "")
    file_contents = conf.file_contents
    file_path = conf.file_path
    content_type = conf.content_type
  }]
}
