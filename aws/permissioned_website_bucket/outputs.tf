output "bucket" {
  value = module.bucket
}

output "cloudfront_origin" {
  value = {
    origin_id = var.origin_id == "" ? var.bucket_name : var.origin_id
    regional_domain_name = module.bucket.bucket.bucket_regional_domain_name
  }
}
