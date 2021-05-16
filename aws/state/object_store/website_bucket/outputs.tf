output bucket {
  value = module.bucket.bucket
}

output bucket_name {
  value = module.bucket.bucket_name
}

output cloudfront_origin {
  value = {
    origin_id = local.bucket_name
    regional_domain_name = module.bucket.bucket.bucket_regional_domain_name
  }
}

output domain_parts {
  value = {
    domain_name = local.domain_name
    top_level_domain = local.top_level_domain
    controlled_domain_part = local.controlled_domain_part
  }
}
