module site_assets {
  source = "../coordinators/asset_directory"
  asset_directory_root = var.asset_directory_root
  s3_asset_prefix = var.s3_asset_prefix
}

module site_static_assets {
  source = "../s3_directory"
  bucket_name = var.bucket_name
  file_configs = module.site_assets.file_configs
}
