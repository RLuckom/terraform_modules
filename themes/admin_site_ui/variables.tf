variable file_prefix {
  type = string
  default = ""
}

variable plugin_configs {
  type = list(object({
    name = string
    slug = string
  }))
  default = []
}

locals {
  file_prefix = trim(var.file_prefix, "/")
  styles_path = "${local.file_prefix}/assets/styles/styles.css"
  files = [
    {
      key = "${local.file_prefix}/index.html"
      file_path = ""
      file_contents = templatefile("${path.module}/src/index.html", {
      styles_path = local.styles_path
      plugin_configs = var.plugin_configs
    })
      content_type = "text/html"
    },
    {
      key = "${local.file_prefix}/favicon.ico"
      file_contents = null
      file_path = "${path.module}/src/favicon.ico"
      content_type = "image/x-icon"
    },
    {
      key = local.styles_path
      file_contents = null
      file_path = "${path.module}/src/styles.css"
      content_type = "text/css"
    },
  ]
}

output files {
  value = [ for conf in local.files : {
    key = trimprefix(conf.key, "/")
    file_contents = conf.file_contents
    file_path = conf.file_path
    content_type = conf.content_type
  }]
}

output default_styles_path {
  value = local.styles_path
}
