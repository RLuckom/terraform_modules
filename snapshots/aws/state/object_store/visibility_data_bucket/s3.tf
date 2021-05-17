module "bucket" {
  source = "../bucket"
  name = var.name
  acl    = "private"
  lambda_notifications = var.lambda_notifications
  lifecycle_rules = var.lifecycle_rules
  prefix_athena_query_permissions = var.prefix_athena_query_permissions
  prefix_object_permissions = var.prefix_object_permissions
  bucket_permissions = var.bucket_permissions
}