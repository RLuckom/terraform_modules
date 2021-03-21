/*
The visibility bucket is where we keep query-able data like cloudfront and lambda logs
*/
module visibility_bucket {
  source = "github.com/RLuckom/terraform_modules//aws/state/object_store/visibility_data_bucket"
  name = local.visibility_data_bucket
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
    local.visibility_prefix_object_permissions 
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
  name = local.cloudfront_delivery_bucket
  lambda_notifications = local.archive_function_cloudfront_delivery_bucket_notifications
}

module data_warehouse {
  source = "github.com/RLuckom/terraform_modules//aws/state/data_warehouse"
  for_each = local.data_warehouse_configs
  data_bucket = local.visibility_data_bucket
  scope = each.value.security_scope
  database_name = each.value.glue_database_name
  table_configs = each.value.glue_table_configs
  table_permission_names = zipmap(
    keys(each.value.glue_table_configs),
    [for k in keys(each.value.glue_table_configs) : {
      add_partition_permission_names = concat(
        [module.archive_function.role.name],
        lookup(lookup(var.glue_permission_name_map, each.value.security_scope, {}), k, 
        {
          add_partition_permission_names = []
          query_permission_names = [] 
          add_partition_permission_arns = []
          query_permission_arns = [] 
        }
      ).add_partition_permission_names 

      )
      query_permission_names = lookup(lookup(var.glue_permission_name_map, each.value.security_scope, {}), k, 
        { 
          add_partition_permission_names = []
          query_permission_names = [] 
          add_partition_permission_arns = []
          query_permission_arns = [] 
        }
      ).query_permission_names 
    }]
  )
}

module archive_function {
  source = "github.com/RLuckom/terraform_modules//aws/donut_days_function"
  timeout_secs = 15
  mem_mb = 128
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
