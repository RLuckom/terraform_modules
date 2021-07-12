variable unique_suffix {
  type = string
  default = ""
}

output asset_directory_root {
  value = "${path.module}/assets"
}
