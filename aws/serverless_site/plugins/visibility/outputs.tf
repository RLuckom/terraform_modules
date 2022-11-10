output additional_connect_sources_required {
  value = [
    "https://s3.amazonaws.com", 
    "https://dynamodb.${var.region}.amazonaws.com",
    "https://${var.cost_report_summary_location.bucket}.s3.amazonaws.com", 
    "https://athena.${var.region}.amazonaws.com",
    "https://${var.plugin_config.bucket_name}.s3.amazonaws.com"
  ]
}

output files {
  value = module.ui.files
}

output plugin_config {
  value = {
    name = var.name
    slug = "explore system metrics"
  }
}

output static_config {
  value = {
    api_name = var.name
    display_name = var.name
    role_name_stem = var.name
  }
}
