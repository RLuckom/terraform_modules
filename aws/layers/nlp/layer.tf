variable layer_name {
  default = "nlp"
}

resource "aws_lambda_layer_version" "layer" {
  layer_name = var.layer_name
  s3_bucket = "rluckom-public-layer-archives"
  s3_key = "nlp"
  s3_object_version = "4S06_Y_55g2LmHvrqz_3SEB6rD7KfJ4t"
  compatible_runtimes = ["nodejs12.x"]
  lifecycle {
    create_before_destroy = true
  }
}

output layer {
  value = aws_lambda_layer_version.layer
}
