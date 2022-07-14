locals {
  layer_key = var.layer_key == "" ? "layers/${var.layer_name}/layer.zip" : var.layer_key
  layer_zip_output_path = var.layer_zip_output_path == "" ? "${path.root}/layers/${var.layer_name}/layer.zip" : var.layer_zip_output_path
}

data "archive_file" "deployment_package" {
  type        = "zip"
  source_dir  = var.layer_path
  output_path = local.layer_zip_output_path
}

resource "aws_s3_object" "deployment_package_zip" {
  bucket = var.source_bucket
  key    = local.layer_key
  source = local.layer_zip_output_path

  etag = data.archive_file.deployment_package.output_md5
}

resource "aws_lambda_layer_version" "layer" {
  layer_name = var.layer_name
  s3_bucket = var.source_bucket
  s3_key = local.layer_key
  compatible_runtimes = ["nodejs12.x"]
  source_code_hash = data.archive_file.deployment_package.output_base64sha256
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [aws_s3_object.deployment_package_zip]
}
