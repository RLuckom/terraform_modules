variable layer_name {
  default = "donut_days"
}

resource "aws_lambda_layer_version" "layer" {
  layer_name = var.layer_name
  s3_bucket = "rluckom-public-layer-archives"
  s3_key = "donut_days"
  s3_object_version = "inFzAKiJpJruuXYGv8.UnBOJ74i7Qaei"
  compatible_runtimes = ["nodejs12.x"]
  lifecycle {
    create_before_destroy = true
  }
}

output layer {
  value = aws_lambda_layer_version.layer
}
