output role {
  value = module.error_relay.role
}

output lambda {
  value = module.error_relay.lambda
}

output notification_configs {
  value = {
    notify_failure_only = local.notify_failure_only
    notify_success_only = local.notify_success_only
    notify_failure_and_success = local.notify_failure_and_success
  }
}

output lambda_logging_roles {
  value = module.error_relay.role.arn
}
