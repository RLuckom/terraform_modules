/*
The visibility bucket is where we keep query-able data like cloudfront and lambda logs
*/
module visibility_bucket {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/visibility_data_bucket"
  unique_suffix = var.unique_suffix
  name = local.visibility_data_bucket
  account_id = var.account_id
  region = var.region
  force_destroy = var.allow_bucket_delete
  // In the following list, the `prefix` of each record comes from the visibility data
  // coordinator. This protects us from cases where an error in the logging module
  // sets the log prefix incorrectly. By using the prefix from the coordinator, we
  // ensure that writes to any incorrect location will fail.
  prefix_athena_query_permissions = concat(
    local.visibility_prefix_athena_query_permissions,
    local.archive_function_visibility_prefix_athena_query_permissions,
    module.site_metric_function.prefix_athena_query_permissions,
  )
  cors_rules = var.visibility_bucket_cors_rules
  prefix_object_permissions = concat(
    local.archive_function_visibility_bucket_permissions,
    local.visibility_prefix_object_permissions, 
    flatten([
      module.cost_report_function.destination_permission_needed,
      {
        permission_type = "read_known_objects"
        prefix = local.cost_report_prefix
        arns = var.cost_report_summary_reader_arns
      }
    ]),
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
  unique_suffix = var.unique_suffix
  account_id = var.account_id
  region = var.region
  name = local.cloudfront_delivery_bucket
  lambda_notifications = local.archive_function_cloudfront_delivery_bucket_notifications
  force_destroy = var.allow_bucket_delete
}

module cost_report_delivery_bucket {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/bucket"
  account_id = var.account_id
  unique_suffix = var.unique_suffix
  region = var.region
  name = local.cost_report_bucket
  force_destroy = var.allow_bucket_delete
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
  report_name                = var.unique_suffix == "" ? "overall-cost-report" : "overall-cost-report-${var.unique_suffix}"
  time_unit                  = "HOURLY"
  format                     = "textORcsv"
  compression                = "GZIP"
  additional_schema_elements = ["RESOURCES"]
  s3_bucket                  = module.cost_report_delivery_bucket.bucket_name
  s3_region                  = var.region
  report_versioning = "OVERWRITE_REPORT"
}

resource random_id metric_table_suffixes {
  for_each = toset(local.system_ids.*.security_scope)
  byte_length = 4
}

module error_table {
  source = "github.com/RLuckom/terraform_modules//aws/state/permissioned_dynamo_table"
  account_id = var.account_id
  region = var.region
  unique_suffix = var.unique_suffix
  partition_key = {
    name = "functionArn",
    type = "S"
  }
  range_key = {
    name = "isoTime",
    type = "S"
  }
  ttl = [{
    enabled = true
    attribute_name = "ttl"
  }]
  table_name = var.error_table_name
  read_permission_role_names = var.error_table_read_permission_role_names
  put_item_permission_role_names = [module.error_relay_function.role.name]
}

module error_relay_function {
  source = "github.com/RLuckom/terraform_modules//aws/utility_functions/error_relay"
  unique_suffix = var.unique_suffix
  account_id = var.account_id
  region = var.region
  security_scope = "visibility"
  donut_days_layer = var.donut_days_layer
  error_metric_ttl_days = var.error_metric_ttl_days
  slack_credentials_parameterstore_key = var.slack_credentials_parameterstore_key
  slack_channel = var.error_relay_slack_channel
  dynamo_error_table = module.error_table.table_name
}

module metric_tables {
  for_each = toset(keys(local.metric_table_configs))
  source = "github.com/RLuckom/terraform_modules//aws/state/permissioned_dynamo_table"
  account_id = var.account_id
  region = var.region
  unique_suffix = var.unique_suffix
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
  put_item_permission_role_names = [ for arn in flatten(values(lookup(var.supported_system_clients, each.key, {
    subsystems = {
      visibility = {
        glue_permission_name_map = {
          add_partition_permission_names = []
          add_partition_permission_arns = []
          query_permission_names = []
          query_permission_arns = []
        }
        site_metric_table_read_role_name_map = {}
        scoped_logging_functions = [
          module.archive_function.role.arn, 
          module.cost_report_function.role.arn,
          module.site_metric_function.role.arn,
        ]
      }
    }
    function_metric_table_read_role_names = []
  }).subsystems).*.scoped_logging_functions) : split("/", arn)[1]] 
}

module site_metric_tables {
  for_each = toset(keys(local.serverless_site_configs))
  source = "github.com/RLuckom/terraform_modules//aws/state/permissioned_dynamo_table"
  account_id = var.account_id
  region = var.region
  unique_suffix = var.unique_suffix
  partition_key = {
    name = "metricType",
    type = "S"
  }
  range_key = {
    name = "metricId",
    type = "S"
  }
  table_name = "${each.key}-metrics"
  read_permission_role_names = concat(
    lookup(var.supported_system_clients[local.serverless_site_configs[each.key].system_id.security_scope].subsystems[local.serverless_site_configs[each.key].subsystem_name].site_metric_table_read_role_name_map, each.key, []),
    []
  )
  write_permission_role_names = []
}

module site_metric_function {
  source = "github.com/RLuckom/terraform_modules//aws/utility_functions/cloudfront_request_summarizer"
  unique_suffix = var.unique_suffix
  account_id = var.account_id
  region = var.region
  logging_config = local.lambda_logging_config
  // Ordinarily this would be in the dynamo module, but roles can only have 10 policies attached, and this allows us to use only one for all the tables
  policy_statements = [ 
    {
      actions = [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchGetItem",
        "dynamodb:PartiQLSelect",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:PartiQLDelete",
        "dynamodb:PartiQLInsert",
        "dynamodb:PartiQLUpdate",
      ]
      resources = [for k in keys(local.serverless_site_configs) : module.site_metric_tables[k].table_arn]
    }
  ]
  security_scope = "visibility"
  donut_days_layer = var.donut_days_layer
  csv_parser_layer = var.csv_parser_layer
  site_metric_configs = [ for site_name, config in local.serverless_site_configs : {
    glue_db = config.glue_database_name
    glue_table = config.glue_table_name
    catalog = local.athena_catalog
    result_location = config.lambda_athena_result_location
    result_prefix = config.lambda_result_prefix
    data_prefix = config.cloudfront_log_storage_prefix
    dynamo_table_name = config.site_metrics_table
  }]
}

module data_warehouse {
  source = "github.com/RLuckom/terraform_modules//aws/state/data_warehouse"
  for_each = local.data_warehouse_configs
  unique_suffix = var.unique_suffix
  data_bucket = module.visibility_bucket.bucket_name
  scope = each.value.security_scope
  database_name = each.value.glue_database_name
  table_configs = each.value.glue_table_configs
  table_permission_names = {
    query_permission_names = distinct(concat(
      flatten([for k, table_config in each.value.glue_table_configs : 
      lookup(lookup(var.supported_system_clients, each.value.security_scope, {
        subsystems = {}
        function_metric_table_read_role_names = []
      }).subsystems, table_config.subsystem_name, {
        glue_permission_name_map = {
          add_partition_permission_names = []
          add_partition_permission_arns = []
          query_permission_names = []
          query_permission_arns = []
        }
        serverless_site_configs = {}
        scoped_logging_functions = []
        site_metric_table_read_role_name_map = {}
      }).glue_permission_name_map.query_permission_names
    ]), [module.site_metric_function.role.name]))
    add_partition_permission_names = distinct(concat(
      [module.archive_function.role.name],
      flatten([for k, table_config in each.value.glue_table_configs : 
      lookup(lookup(var.supported_system_clients, each.value.security_scope, {
        subsystems = {}
        function_metric_table_read_role_names = []
      }).subsystems, table_config.subsystem_name, {
        glue_permission_name_map = {
          add_partition_permission_names = []
          add_partition_permission_arns = []
          query_permission_names = []
          query_permission_arns = []
        }
        serverless_site_configs = {}
        scoped_logging_functions = []
        site_metric_table_read_role_name_map = {}
      }).glue_permission_name_map.add_partition_permission_names
    ])))
  }
}

module cost_report_function {
  source = "github.com/RLuckom/terraform_modules//aws/utility_functions/cur_report_parser"
  unique_suffix = var.unique_suffix
  account_id = var.account_id
  region = var.region
  logging_config = local.lambda_logging_config
  security_scope = "visibility"
  donut_days_layer = var.donut_days_layer
  csv_parser_layer = var.csv_parser_layer
  io_config = {
    input_config = {
      bucket = module.cost_report_delivery_bucket.bucket_name
      prefix = ""
    }
    output_config = {
      bucket = module.visibility_bucket.bucket_name
      prefix = local.cost_report_prefix
    }
  }
}

module archive_function {
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  unique_suffix = var.unique_suffix
  timeout_secs = 20
  mem_mb = 256
  account_id = var.account_id
  region = var.region
  logging_config = local.lambda_logging_config
  log_level = var.log_level
  config_contents = templatefile("${path.module}/src/configs/s3_to_athena.js",
  {
    athena_region = var.athena_region
    glue_db_map = jsonencode(local.archive_function_destination_maps.glue_db_map)
    glue_table_map = jsonencode(local.archive_function_destination_maps.glue_table_map)
    athena_catalog = local.athena_catalog
    athena_destinations_map = jsonencode(local.archive_function_destination_maps.athena_destinations_map)
    log_destinations_map = jsonencode(local.archive_function_destination_maps.log_destination_map)
    partition_bucket = module.visibility_bucket.bucket_name
  })
  lambda_event_configs = module.error_relay_function.notification_configs.notify_failure_only
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
