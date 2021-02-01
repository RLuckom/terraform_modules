output layer {
  // this value specifies 'present' because we need a non-aws-generated value to use in 
  // count configs
  value = {
    present = true
    arn = aws_lambda_layer_version.layer
  }
}
