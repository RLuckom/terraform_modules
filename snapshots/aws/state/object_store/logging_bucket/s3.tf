module bucket {
  source = "../bucket"
  unique_suffix = var.unique_suffix
  force_destroy = var.force_destroy
  name = var.name
  account_id = var.account_id
  region = var.region
  grant_based_acl    = [
    {
      owner_full_control = true
      group_grants = [
        {
          grantee_uri = "http://acs.amazonaws.com/groups/s3/LogDelivery"
          permission = "READ_ACP"
        },
        {
          grantee_uri = "http://acs.amazonaws.com/groups/s3/LogDelivery"
          permission = "WRITE"
        },
      ]
      # see https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/AccessLogs.html#AccessLogsBucketAndFileOwnership
      id_grants = [
        {
          grantee_id = "c4c1ede66af53448b93c283ce9448c4ba468c9432aa01d700d3878632f77d2d0"
          grantee_type = "CanonicalUser"
          permission = "FULL_CONTROL"
        }
      ]
    }
  ]
  lambda_notifications = var.lambda_notifications 
  prefix_object_permissions = var.prefix_object_permissions
  bucket_permissions = var.bucket_permissions
  lifecycle_rules = var.lifecycle_rules
}
