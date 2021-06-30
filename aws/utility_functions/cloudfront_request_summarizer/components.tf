module request_record_lambda {
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  account_id = var.account_id
  region = var.region
  cron_notifications = [{
    period_expression = "01 * * * ? *"
  }]
  config_contents = templatefile("${path.module}/src/backend/parse_requests_config.js",
  {
    athena_result_bucket = ""
    athena_region = ""
    athena_catalog = ""
    result_bucket = ""
    result_path = ""
    table_name = var.posts_table_name
    db_name = var.posts_table_name
    table_region = var.region
  })
  logging_config = var.logging_config
  lambda_event_configs = var.lambda_event_configs
  action_name = "post_entry"
  scope_name = var.coordinator_data.system_id.security_scope
  donut_days_layer = var.donut_days_layer
  additional_layers = [var.markdown_tools_layer]
}

module ui {
  source = "github.com/RLuckom/terraform_modules//themes/icknield/admin_site_plugin_ui"
  name = var.name
  region = var.region
  account_id = var.account_id
  gopher_config_contents = file("${path.module}/src/frontend/libs/gopher_config.js")
  admin_site_resources = var.admin_site_resources
  plugin_config = var.plugin_config
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
