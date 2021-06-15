/*
The visibility bucket is where we keep query-able data like cloudfront and lambda logs
*/
module visibility_bucket {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/visibility_data_bucket"
  name = local.visibility_data_bucket
  account_id = var.account_id
  region = var.region
  // In the following list, the `prefix` of each record comes from the visibility data
  // coordinator. This protects us from cases where an error in the logging module
  // sets the log prefix incorrectly. By using the prefix from the coordinator, we
  // ensure that writes to any incorrect location will fail.
  prefix_athena_query_permissions = concat(
    local.visibility_prefix_athena_query_permissions,
    local.archive_function_visibility_prefix_athena_query_permissions
  )
  prefix_object_permissions = concat(
    local.archive_function_visibility_bucket_permissions,
    local.visibility_prefix_object_permissions, 
    [module.cost_report_function.destination_permission_needed]
  )
  lifecycle_rules = local.visibility_lifecycle_rules
}

/*
This is the bucket where cloudfront delivers its logs.
Cloudfront requires full access (create, read, update, delete) to any bucket where it delivers
logs, so we use a dedicated bucket for this instead of giving cloudfront full access to our
permanent data bucket. When cloudfront drops logs into this bucket, an archiver function picks them up
and moves them into the visibility bucket.
*/
module log_delivery_bucket {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/logging_bucket"
  account_id = var.account_id
  region = var.region
  name = local.cloudfront_delivery_bucket
  lambda_notifications = local.archive_function_cloudfront_delivery_bucket_notifications
}

module cost_report_delivery_bucket {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/bucket"
  account_id = var.account_id
  region = var.region
  name = local.cost_report_bucket
  lambda_notifications = [module.cost_report_function.lambda_notification_config]
  principal_bucket_permissions = [{
    permission_type = "allow_billing_report"
    principals = [{
      type = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }]
  }]
  principal_prefix_object_permissions = [{
    permission_type = "put_object"
    prefix = ""
    principals = [{
      type = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }]
  }]
  prefix_list_permissions = []
  prefix_object_permissions = [
  ]
}

resource aws_cur_report_definition cost_report_definition {
  report_name                = "overall-cost-report"
  time_unit                  = "HOURLY"
  format                     = "textORcsv"
  compression                = "GZIP"
  additional_schema_elements = ["RESOURCES"]
  s3_bucket                  = local.cost_report_bucket
  s3_region                  = var.region
  report_versioning = "OVERWRITE_REPORT"
}

resource random_id metric_table_suffixes {
  for_each = toset(local.system_ids.*.security_scope)
  byte_length = 4
}

module metric_tables {
  for_each = toset(keys(local.metric_table_configs))
  source = "github.com/RLuckom/terraform_modules//aws/state/permissioned_dynamo_table"
  partition_key = {
    name = "invokedFunctionArn",
    type = "S"
  }
  range_key = {
    name = "time",
    type = "N"
  }
  table_name = local.metric_table_configs[each.key].table_name
  read_permission_role_names = local.metric_table_read_roles[each.key].read_role_names
  put_item_permission_role_names = [ for arn in flatten([
    [ for security_scope, config in var.supported_system_clients : [
      for subsystem_name, subsystem_config in config.subsystems : subsystem_config.scoped_logging_functions
    ]], [module.archive_function.role.arn]]
  ) : split("/", arn)[1]] 
}

module data_warehouse {
  source = "github.com/RLuckom/terraform_modules//aws/state/data_warehouse"
  for_each = local.data_warehouse_configs
  data_bucket = local.visibility_data_bucket
  scope = each.value.security_scope
  database_name = each.value.glue_database_name
  table_configs = each.value.glue_table_configs
  table_permission_names = {
    query_permission_names = distinct(
      flatten([for k, table_config in each.value.glue_table_configs : 
      lookup(lookup(var.supported_system_clients, each.value.security_scope, {
        subsystems = {}
        metric_table_read_role_names = []
      }).subsystems, table_config.subsystem_name, {
        glue_permission_name_map = {
          add_partition_permission_names = []
          add_partition_permission_arns = []
          query_permission_names = []
          query_permission_arns = []
        }
        serverless_site_configs = {}
        scoped_logging_functions = []
      }).glue_permission_name_map.query_permission_names
    ]))
    add_partition_permission_names = distinct(concat(
      [module.archive_function.role.name],
      flatten([for k, table_config in each.value.glue_table_configs : 
      lookup(lookup(var.supported_system_clients, each.value.security_scope, {
        subsystems = {}
        metric_table_read_role_names = []
      }).subsystems, table_config.subsystem_name, {
        glue_permission_name_map = {
          add_partition_permission_names = []
          add_partition_permission_arns = []
          query_permission_names = []
          query_permission_arns = []
        }
        serverless_site_configs = {}
        scoped_logging_functions = []
      }).glue_permission_name_map.add_partition_permission_names
    ])))
  }
}

module cost_report_function {
  source = "github.com/RLuckom/terraform_modules//aws/utility_functions/cur_report_parser"
  account_id = var.account_id
  region = var.region
  logging_config = local.lambda_logging_config
  security_scope = "visibility"
  donut_days_layer = var.donut_days_layer
  csv_parser_layer = var.csv_parser_layer
  io_config = {
    input_config = {
      bucket = local.cost_report_bucket
      prefix = ""
    }
    output_config = {
      bucket = local.visibility_data_bucket
      prefix = local.cost_report_prefix
    }
  }
}

module archive_function {
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  timeout_secs = 15
  mem_mb = 128
  account_id = var.account_id
  region = var.region
  logging_config = local.lambda_logging_config
  log_level = var.log_level
  config_contents = templatefile("${path.module}/src/configs/s3_to_athena.js",
  {
    athena_region = var.athena_region
    glue_db_map = jsonencode(local.archive_function_destination_maps.glue_db_map)
    glue_table_map = jsonencode(local.archive_function_destination_maps.glue_table_map)
    athena_catalog = "AwsDataCatalog"
    athena_destinations_map = jsonencode(local.archive_function_destination_maps.athena_destinations_map)
    log_destinations_map = jsonencode(local.archive_function_destination_maps.log_destination_map)
    partition_bucket = local.visibility_data_bucket
  })
  lambda_event_configs = var.lambda_event_configs
  additional_helpers = [
    {
      helper_name = "athenaHelpers.js",
      file_contents = file("${path.module}/src/helpers/athenaHelpers.js")
    }
  ]
  action_name = "cloudfront_log_collector"
  scope_name = "visibility"
  donut_days_layer = var.donut_days_layer
}
