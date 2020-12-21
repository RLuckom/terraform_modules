module "bucket" {
  source = "../permissioned_bucket"
  bucket = "logs.${var.bucket_name}"
  acl    = "log-delivery-write"
}
