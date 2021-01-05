output "bucket" {
  value = module.bucket.bucket
}

output permission_sets {
  value = module.bucket.permission_sets
}

output "cloudfront_logging" {
  value = {
    include_cookies = var.include_cookies
    bucket_id = module.bucket.bucket.id
  }
}
