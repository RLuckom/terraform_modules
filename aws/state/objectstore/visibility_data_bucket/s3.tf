locals {
  prefix_put_permissions = [ for prefix_config in var.prefix_put_permissions : {
    prefix = prefix_config.prefix
    actions = [
      "s3:PutObject",
      "s3:ListMultipartUploadParts"
    ]
    principals = [
      {
        type = "AWS"
        identifiers = prefix_config.arns 
      }
    ]
  }]
  prefix_athena_query_permissions = [ for prefix_config in var.prefix_athena_query_permissions : {
    prefix = prefix_config.prefix
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    principals = [
      {
        type = "AWS"
        identifiers = prefix_config.arns 
      }
    ]
  }]
  list_bucket_permissions = {
    actions = [
      "s3:ListBucket",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation"
    ]
    principals = [
      {
        type = "AWS"
        identifiers = var.list_bucket_permission_arns
      }
    ]
  }
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
    local.prefix_athena_query_permissions,
    var.object_policy_statements
  )
  bucket_policy_statements = concat(
    length(local.list_bucket_permissions.principals[0].identifiers) > 0 ? [local.list_bucket_permissions] : [],
    var.bucket_policy_statements
  )
}
