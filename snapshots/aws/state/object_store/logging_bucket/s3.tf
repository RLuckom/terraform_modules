module bucket {
  source = "../bucket"
  name = var.name
  account_id = var.account_id
  region = var.region
  acl    = "log-delivery-write"
  lambda_notifications = var.lambda_notifications 
  prefix_object_permissions = var.prefix_object_permissions
  bucket_permissions = var.bucket_permissions
  lifecycle_rules = var.lifecycle_rules
}
