variable name {
  type = string
}

variable region {
  type = string
}

variable account_id {
  type = string
}

variable gopher_config_contents {
  type = string
}

variable unique_suffix {
  type = string
  default = ""
}

variable admin_site_resources {
  type = object({
    default_styles_path = string
    default_scripts_path = string
    aws_script_path = string
    exploranda_script_path = string
    lodash_script_path = string
    header_contents = string
    footer_contents = string
    site_description = string
    site_title = string
  })
  default = {
    aws_script_path = ""
    exploranda_script_path = ""
    lodash_script_path = ""
    default_styles_path = ""
    default_scripts_path = ""
    header_contents = "<div class=\"header-block\"><h1 class=\"heading\">Private Site</h1></div>"
    footer_contents = "<div class=\"footer-block\"><h1 class=\"footing\">Private Site</h1></div>"
    site_title = "running_material.site_title"
    site_description = "running_material.site_description"
  }
}

variable include_aws {
  type = bool
  default = true
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

variable config_values {
  type = any
  default = {}
}

variable i18n_config_values {
  type = any
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

locals {
  file_prefix = trim(var.plugin_config.source_root, "/")
  config_path = "${local.file_prefix}/assets/js/config.js"
  utils_js_path = "${local.file_prefix}/assets/js/utils-${filemd5("${path.module}/src/frontend/libs/utils.js")}.js"
  gopher_config_js_path = "${local.file_prefix}/assets/js/gopher_config-${md5(var.gopher_config_contents)}.js"
  js_prefix = "${local.file_prefix}assets/js/"
  i18n_config = var.i18n_config_values
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
  default_script_paths = concat(
    var.include_aws ? [var.admin_site_resources.aws_script_path] : [],
    [
      var.admin_site_resources.lodash_script_path,
      var.admin_site_resources.exploranda_script_path,
      local.config_path,
      local.gopher_config_js_path,
      local.utils_js_path,
    ],
    var.default_script_paths,
  )
  files = flatten([
    [for page_name, page_config in var.page_configs : {
      key = "${local.file_prefix}${page_name}.html"
      file_path = null
      file_contents = templatefile("${path.module}/src/frontend/index.html", {
      running_material = var.admin_site_resources
      css_paths = concat(
        local.default_css_paths,
        page_config.css_paths
      )
      script_paths = concat(
        local.default_script_paths,
        page_config.script_paths,
        ["${local.file_prefix}/assets/js/${page_name}-${filemd5(page_config.render_config_path)}.js"],
      )
      deferred_script_paths = concat(
        local.default_deferred_script_paths,
        page_config.deferred_script_paths
      )
    })
      content_type = "text/html"
    }],
    [for page_name, page_config in var.page_configs : {
      key = "${local.js_prefix}${page_name}-${filemd5(page_config.render_config_path)}.js"
      file_contents = null
      file_path = page_config.render_config_path
      content_type = "application/javascript"
    }],
    var.plugin_file_configs,
    {
      key = local.config_path
      file_contents = <<EOF
window.CONFIG = ${jsonencode(local.plugin_config)}
window.I18N_CONFIG = ${jsonencode(local.i18n_config)}
EOF
      file_path = null
      content_type = "application/javascript"
    },
    {
      key = "${local.file_prefix}/assets/js/gopher_config-${md5(var.gopher_config_contents)}.js"
      file_contents = var.gopher_config_contents
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
