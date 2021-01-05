module "bucket" {
  source = "../permissioned_bucket"
  bucket = "logs.${var.bucket_name}"
  acl    = "log-delivery-write"
  lambda_notifications = [for sink in var.partitioned_data_sink : {
    lambda_arn = sink.lambda_arn
    lambda_name = sink.lambda_name
    filter_prefix = sink.filter_prefix
    filter_suffix = sink.filter_suffix
  }]
}
