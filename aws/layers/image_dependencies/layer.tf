variable layer_name {
  default = "image_dependencies"
}

resource "aws_lambda_layer_version" "layer" {
  layer_name = var.layer_name
  s3_bucket = "rluckom-public-layer-archives"
  s3_key = "image_dependencies"
  s3_object_version = "GbuP1S6HIqAqF_4DYr8Nm72Xq4QG4NS7"
  compatible_runtimes = ["nodejs12.x"]
  lifecycle {
    create_before_destroy = true
  }
}

output layer {
  value = aws_lambda_layer_version.layer
}
