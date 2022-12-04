variable layer_name {
  default = "activitypub_utils"
}

resource "aws_lambda_layer_version" "layer" {
  layer_name = var.layer_name
  s3_bucket = "rluckom-public-layer-archives"
  s3_key = "activitypub_utils"
  s3_object_version = "wvPCLypYr21fqw45vcId1HqTpqwsep6W"
  compatible_runtimes = ["nodejs12.x"]
  lifecycle {
    create_before_destroy = true
  }
}

output layer {
  value = aws_lambda_layer_version.layer
}

output layer_config {
  // this value specifies 'present' because we need a non-aws-generated value to use in 
  // count configs
  value = {
    present = true
    arn = aws_lambda_layer_version.layer.arn
  }
}
