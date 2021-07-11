output lambda {
  value = module.site_metric_summarizer.lambda
}

output role {
  value = module.site_metric_summarizer.role
}

output prefix_athena_query_permissions {
  value = [ for conf in var.site_metric_configs : 
    {
      log_storage_prefix = conf.data_prefix
      result_prefix = conf.result_prefix
      arns = [module.site_metric_summarizer.role.arn]
    }
  ]
}
