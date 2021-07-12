module "bucket" {
  source = "../bucket"
  unique_suffix = var.unique_suffix
  force_destroy = var.force_destroy
  name = var.name
  acl    = "private"
  account_id = var.account_id
  region = var.region
  cors_rules = var.cors_rules
  lambda_notifications = var.lambda_notifications
  lifecycle_rules = var.lifecycle_rules
  prefix_athena_query_permissions = var.prefix_athena_query_permissions
  prefix_object_permissions = var.prefix_object_permissions
  bucket_permissions = var.bucket_permissions
}
