locals {
  prefix_put_permissions = [ for prefix_config in var.prefix_put_permissions : {
    prefix = prefix_config.prefix
    actions = ["s3:PutObject"]
    principals = [
      {
        type = "AWS"
        identifiers = prefix_config.arns 
      }
    ]
  }]
}

module "bucket" {
  source = "github.com/RLuckom/terraform_modules//aws/state/objectstore/permissioned_bucket"
  bucket = var.bucket_name
  acl    = "log-delivery-write"
  lambda_notifications = [for sink in var.partitioned_data_sink : {
    lambda_arn = sink.lambda_arn
    lambda_name = sink.lambda_name
    filter_prefix = sink.filter_prefix
    filter_suffix = sink.filter_suffix
  }]
  lifecycle_rules = var.lifecycle_rules
  object_policy_statements = concat(
    local.prefix_put_permissions,
    var.object_policy_statements
  )
  bucket_policy_statements = var.bucket_policy_statements
}
