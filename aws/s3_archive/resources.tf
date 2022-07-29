data "archive_file" "deployment_package" {
  type        = "zip"
  source_dir  = var.path
  output_path = var.output_path
}

resource "aws_s3_object" "archive_zip" {
  bucket = var.bucket
  key    = var.key
  source = var.output_path
  etag   = data.archive_file.deployment_package.output_md5
}
