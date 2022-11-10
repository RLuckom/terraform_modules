module replication_lambda {
  source = "../../../utility_functions/replicator"
  unique_suffix = var.unique_suffix
  logging_config = var.replication_function_logging_config
  account_id = var.account_id
  region = var.region
  replication_time_limit = 15
  replication_memory_size = 256
  lambda_event_configs = var.replication_lambda_event_configs
  security_scope = var.security_scope
  replication_configuration = {
    role_arn = ""
    donut_days_layer = var.donut_days_layer_config
    rules = local.rules
  }
}

module replica_bucket_1 {
  source = "../bucket"
  unique_suffix = var.unique_suffix
  name = local.buckets[0]
  force_destroy = var.really_allow_delete
  account_id = var.account_id
  region = var.region1
  need_policy_override = var.need_policy_override
  versioning = [{
    enabled = true
  }]
  prefix_object_permissions = module.replication_lambda.replication_function_permissions_needed[local.buckets[0]]
  providers = {
    aws = aws.replica1
  }
}

module replica_bucket_2 {
  source = "../bucket"
  unique_suffix = var.unique_suffix
  name = local.buckets[1]
  force_destroy = var.really_allow_delete
  account_id = var.account_id
  region = var.region2
  need_policy_override = var.need_policy_override
  versioning = [{
    enabled = true
  }]
  prefix_object_permissions = module.replication_lambda.replication_function_permissions_needed[local.buckets[1]]
  providers = {
    aws = aws.replica2
  }
}

module replica_bucket_3 {
  source = "../bucket"
  unique_suffix = var.unique_suffix
  name = local.buckets[2]
  force_destroy = var.really_allow_delete
  account_id = var.account_id
  region = var.region3
  need_policy_override = var.need_policy_override
  prefix_object_permissions = module.replication_lambda.replication_function_permissions_needed[local.buckets[2]]
  versioning = [{
    enabled = true
  }]
  providers = {
    aws = aws.replica3
  }
}
