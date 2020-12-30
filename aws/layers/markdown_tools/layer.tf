variable layer_name {
  default = "markdown_tools"
}

resource "aws_lambda_layer_version" "layer" {
  layer_name = var.layer_name
  s3_bucket = "rluckom-public-layer-archives"
  s3_key = "markdown_tools"
  s3_object_version = "y2Dp.iNEbkomgIFHijSIYEYuxjt5Jvah"
  compatible_runtimes = ["nodejs12.x"]
  lifecycle {
    create_before_destroy = true
  }
}

output layer {
  value = aws_lambda_layer_version.layer
}
