output visibility_lifecycle_rules {
  value = concat(
    local.cloudfront_log_path_lifecycle_rules,
    local.lambda_log_path_lifecycle_rules,
    local.athena_result_path_lifecycle_rules
  )
}

output visibility_data_bucket {
  value = module.visibility_bucket.bucket_name
}

output cloudfront_delivery_bucket {
  value = module.log_delivery_bucket.bucket_name
}

output data_warehouse_configs {
  value = local.data_warehouse_configs
}

output serverless_site_configs {
  value = local.serverless_site_configs
}

output lambda_source_bucket {
  value = var.lambda_source_bucket
}

output lambda_log_configs {
  value = local.lambda_log_configs
}

output metric_table_configs {
  value = local.metric_table_configs
}

output cost_report_prefix {
  value = local.cost_report_prefix
}

output error_relay_notification_configs {
  value = module.error_relay_function.notification_configs
}

output error_table_metadata {
  value = module.error_table.table_metadata
}

output cost_report_summary_location {
  value = {
    bucket = module.visibility_bucket.bucket_name
    key = module.cost_report_function.report_summary_key
  }
}
