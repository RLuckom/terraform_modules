module "bucket" {
  source = "../permissioned_bucket"
  bucket = var.bucket_name
  acl    = "public-read"

  website_configs = [{
    index_document = "index.html"
    error_document = "error.html"
  }]

  cors_rules =[{
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = var.allowed_origins == [] ? ["https://${var.bucket_name}"] : var.allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }]

  object_policy_statements = [{
    actions = ["s3:GetObject", "s3:GetObjectVersion"]
    principals = [{
      type = "*"
      identifiers = ["*"]
    }]
  }]
  lambda_notifications = var.lambda_notifications
}
