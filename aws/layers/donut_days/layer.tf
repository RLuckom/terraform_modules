variable layer_name {
  default = "donut_days"
}

resource "aws_lambda_layer_version" "layer" {
  layer_name = var.layer_name
  s3_bucket = "rluckom-public-layer-archives"
  s3_key = "donut_days"
  s3_object_version = "dxBKKXFgsz5SYwkWoHxL8T7_5IC8sl0D"
  compatible_runtimes = ["nodejs12.x"]
  lifecycle {
    create_before_destroy = true
  }
}

output layer {
  value = aws_lambda_layer_version.layer
}
