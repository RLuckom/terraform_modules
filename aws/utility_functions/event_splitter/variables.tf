variable action_name {
  type = string
  default = "splitter"
}

variable logging_config {
  type = object({
    bucket = string
    prefix = string
  })
  default = {
    bucket = ""
    prefix = ""
  }
}

variable time_limit {
  type = number
  default = 10
}

variable memory_size {
  type = number
  default = 128
}

variable security_scope {
  type = string
  default = ""
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

variable notifications {
  type = list(object({
    lambda_arn = string
    lambda_name = string
    lambda_role_arn = string
    events = list(string)
    filter_prefix = string
    filter_suffix = string
    permission_type = string
  }))
  default = []
}

locals {
  notifications = [for notif in var.notifications : {
    lambda_arn = notif.lambda_arn
    lambda_name = notif.lambda_name
    lambda_role_arn = notif.lambda_role_arn
    events = notif.events
    filter_prefix = notif.filter_prefix == null ? "" : notif.filter_prefix
    filter_suffix = notif.filter_suffix == null ? "" : notif.filter_suffix
    permission_type = notif.permission_type
  }]
  need_lambda = anytrue([for notif in local.notifications: 
  anytrue([for comp in local.notifications : (
    (length(notif.filter_prefix) <= length(comp.filter_prefix) && substr(comp.filter_prefix, 0, length(notif.filter_prefix)) == notif.filter_prefix) &&
    (length(notif.filter_suffix) <= length(comp.filter_suffix) && substr(comp.filter_suffix, 0, length(notif.filter_suffix)) == notif.filter_suffix) &&
    anytrue([ for event in notif.events : contains(comp.events, event)])
  )])])
  all_prefixes = [for notif in local.notifications : notif.filter_prefix]
  notifications_prefixes = [for prefix in local.all_prefixes : prefix if !anytrue([for comp in local.all_prefixes: length(comp) <= length(prefix) && substr(prefix, 0, length(comp)) == comp])]
  events = setunion((length(var.notifications) > 0 ? [for notif in var.notifications : notif.events] : [[], []])...)
  splitter_notifications = !local.need_lambda ? [] : [for prefix in local.notifications_prefixes : {
    lambda_arn = module.lambda[0].lambda.arn
    lambda_name = module.lambda[0].lambda.function_name
    lambda_role_arn = module.lambda[0].role.arn
    events = local.events
    filter_prefix = prefix
    filter_suffix = ""
    permission_type = ""
  }]
  distinct_lambda_arns = distinct([for notif in var.notifications : notif.lambda_arn])
  need_donut_days_layer = local.need_lambda && var.donut_days_layer.present == false
}
