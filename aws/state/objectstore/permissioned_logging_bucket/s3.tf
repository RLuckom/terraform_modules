locals {
  move_objects_out_permissions = [ for prefix_config in var.move_objects_out_permissions : {
    prefix = prefix_config.prefix
    actions = [
      "s3:DeleteObject",
      "s3:PutObject"
    ]
    principals = [
      {
        type = "AWS"
        identifiers = prefix_config.arns 
      }
    ]
  }]
}

module bucket {
  source = "github.com/RLuckom/terraform_modules//aws/state/objectstore/permissioned_bucket"
  bucket = var.bucket_name
  acl    = "log-delivery-write"
  lambda_notifications = var.lambda_notifications 
  lifecycle_rules = var.lifecycle_rules
  object_policy_statements = concat(
    var.object_policy_statements,
    local.move_objects_out_permissions
  )
  bucket_policy_statements = var.bucket_policy_statements
}
