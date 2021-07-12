variable asset_directory_root {
  type = string
}

variable unique_suffix {
  type = string
  default = ""
}

variable s3_asset_prefix {
  type = string
  default = ""
}

locals {
  file_types = {
    woff2 = "font/woff2"
    woff = "font/woff"
    ttf = "font/ttf"
    tpl = "text/html"
    tmpl = "text/html"
    json = "application/json"
    js = "application/javascript"
    html = "text/html"
    htm = "text/html"
    css = "text/css"
    gif = "image/gif"
    jpg = "image/jpeg"
    jpeg = "image/jpeg"
  }
  filtered_files = [for file_path in fileset(var.asset_directory_root, "**") : file_path if substr(split("/", file_path)[length(split("/", file_path)) - 1],  0, 1) != "."]
  file_hash = zipmap(
    local.filtered_files,
    [for file_path in local.filtered_files : {
      asset_path = "${var.s3_asset_prefix}${file_path}"
      abspath = "${var.asset_directory_root}/${file_path}"
      extension = split(".", file_path)[length(split(".", file_path)) - 1]
    }
  ]
  )
  file_configs = [ for path, config in local.file_hash : {
    key = config.asset_path
    content_type = lookup(local.file_types, config.extension, "application/octet-stream")
    file_path = config.abspath
  }]
}

output file_configs {
  value = local.file_configs
}
