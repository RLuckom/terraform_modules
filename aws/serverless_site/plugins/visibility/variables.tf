variable name {
  type = string
}

variable region {
  type = string
}

variable account_id {
  type = string
}

variable cost_report_summary_location {
  type = object({
    bucket = string
    key = string
  })
}

variable data_warehouse_configs {
  type = any
  default = {}
}

variable serverless_site_configs {
  type = any
  default = {}
}

variable admin_site_resources {
  type = object({
    default_styles_path = string
    default_scripts_path = string
    header_contents = string
    footer_contents = string
    site_title = string
    site_description = string
    aws_script_path = string
    lodash_script_path = string
    exploranda_script_path = string
  })
  default = {
    aws_script_path = ""
    lodash_script_path = ""
    exploranda_script_path = ""
    default_styles_path = ""
    default_scripts_path = ""
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

variable i18n_config_values {
  type = any
  default = {
    total_cost = "Total Cost"
  }
}

locals {
  plugin_default_styles_path = "${local.file_prefix}/assets/styles/default.css"
  file_prefix = trim(var.plugin_config.source_root, "/")
}

// function vars

variable logging_config {
  type = object({
    bucket = string
    prefix = string
    metric_table = string
  })
  default = {
    bucket = ""
    prefix = ""
    metric_table = ""
  }
}

variable csv_parser_layer {
  type = object({
    present = bool
    arn = string
  })
  default = {
    present = false
    arn = ""
  }
}

variable donut_days_layer {
  type = object({
    present = bool
    arn = string
  })
  default = {
    present = false
    arn = ""
  }
}

variable lambda_event_configs {
  type = list(object({
    maximum_event_age_in_seconds = number
    maximum_retry_attempts = number
    on_success = list(object({
      function_arn = string
    }))
    on_failure = list(object({
      function_arn = string
    }))
  }))
  default = []
}
