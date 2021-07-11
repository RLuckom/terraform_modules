module ui {
  source = "../../../../themes/icknield/admin_site_plugin_ui"
  name = var.name
  region = var.region
  account_id = var.account_id
  gopher_config_contents = file("${path.module}/src/frontend/libs/gopher_config.js")
  admin_site_resources = var.admin_site_resources
  plugin_config = var.plugin_config
  i18n_config_values = var.i18n_config_values
  config_values = {
    cost_report_summary_storage_bucket = var.cost_report_summary_location.bucket
    cost_report_summary_storage_key = var.cost_report_summary_location.key 
    data_warehouse_configs = var.data_warehouse_configs
    serverless_site_configs = var.serverless_site_configs
  }
  default_css_paths = [
    local.plugin_default_styles_path,
  ]
  default_script_paths = []
  default_deferred_script_paths = []
  page_configs = {
    index = {
      css_paths = []
      script_paths = []
      deferred_script_paths = []
      render_config_path = "${path.module}/src/frontend/libs/index.js"
    }
  }
  plugin_file_configs = [
    {
      key = local.plugin_default_styles_path
      file_path = ""
      file_contents = file("${path.module}/src/frontend/styles/default.css")
      content_type = "text/css"
    },
  ]
}
