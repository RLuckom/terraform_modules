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

variable manifest_data {
  type = map(string)
  default = {
    name = "my site"
    start_url = "."
    scope = "."
    display = "standalone"
    lang = "en-US"
  }
}

variable admin_running_material {
  type = object({
    site_root_url = string
    site_title = string
    site_description = string
    nav_menu_items = list(object({
      link = string
      title = string
    }))
  })
  default = {
    nav_menu_items = []
    site_root_url = "/"
    site_title = "admin_running_material.site_title"
    site_description = "admin_running_material.site_description"
  }
}

locals {
  header_contents = <<EOF
			<nav class="navbar">
        <a href="${var.admin_running_material.site_root_url}" class="nav-logo">${var.admin_running_material.site_title}</a>
				<ul class="nav-menu">
    ${join("\n", [ for nav_item in var.admin_running_material.nav_menu_items : "<li class=\"nav-item\"><a href=\"${nav_item.link}\" class=\"nav-link\">${nav_item.title}</a></li>"])}
				</ul>
    
				<div class="hamburger">
					<span class="bar"></span>
					<span class="bar"></span>
					<span class="bar"></span>
				</div>
			</nav>
EOF
  footer_contents = ""
  file_prefix = trim(var.file_prefix, "/")
  styles_path = "${local.file_prefix}/assets/styles/styles-${filemd5("${path.module}/src/styles.css")}.css"
  scripts_path = "${local.file_prefix}/assets/js/scripts-${filemd5("${path.module}/src/scripts.js")}.js"
  files = [
    {
      key = "${local.file_prefix}/manifest.json",
      file_path = ""
      file_contents = jsonencode(merge(var.manifest_data, {
        icons = [{
          src = "./favicon.ico"
          type = "image/x-icon" 
        }]
      }))
      content_type = "application/manifest+json"
    },
    {
      key = "${local.file_prefix}/index.html"
      file_path = ""
      file_contents = templatefile("${path.module}/src/index.html", {
        admin_running_material = {
          header_contents = local.header_contents
          footer_contents = local.footer_contents
          site_root_url = var.admin_running_material.site_root_url
          site_title = var.admin_running_material.site_title
          site_description = var.admin_running_material.site_description
        }
        css_paths = [local.styles_path]
        script_paths = []
        deferred_script_paths = [local.scripts_path]
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
    {
      key = local.scripts_path
      file_contents = null
      file_path = "${path.module}/src/scripts.js"
      content_type = "application/javascript"
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

output site_resources {
  value = {
    header_contents = local.header_contents
    footer_contents = local.footer_contents
    default_styles_path = local.styles_path
    default_scripts_path = local.scripts_path
    site_title = var.admin_running_material.site_title 
    site_description = var.admin_running_material.site_description 
  }
}
