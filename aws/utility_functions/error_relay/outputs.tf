output lambda {
  value = module.error_relay
}

output replication_function_permissions_needed {
  value = local.replication_function_prefix_permissions
}

output notify_failure_and_success {
  value = local.notify_failure_and_success
}

output notify_failure_only {
  value = local.notify_failure_only
}

output notify_success_only {
  value = local.notify_success_only
}

output lambda_logging_roles {
  value = module.error_relay.role.arn
}
