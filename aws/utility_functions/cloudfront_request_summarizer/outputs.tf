output lambda {
  value = module.site_metric_summarizer.lambda
}

output role {
  value = module.site_metric_summarizer.role
}

output destination_permission_needed {
  value = [ for conf in var.site_metric_configs : {
    permission_type = "read_write_objects"
    prefix = conf.result_prefix
    arns = [module.site_metric_summarizer.role.arn]
  }]
}
