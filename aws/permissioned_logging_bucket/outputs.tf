output "bucket" {
  value = module.bucket
}

output "cloudfront_logging" {
  value = {
    include_cookies = var.include_cookies
    bucket_id = module.bucket.bucket.id
  }
}
