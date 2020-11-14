output "bucket" {
  value = aws_s3_bucket.bucket
}

output "permission_sets" {
  value = {
    athena_query_execution = [{
      actions   =  [
        "s3:GetObject",
        "s3:ListMultipartUploadParts",
        "s3:PutObject",
        "s3:GetBucketLocation",
        "s3:GetBucketAcl",
        "s3:ListBucket"
      ]
      resources = [
        aws_s3_bucket.bucket.arn,
        "${aws_s3_bucket.bucket.arn}/*"
      ]
    }]
    read_and_tag = [{
      actions   =  [
        "s3:GetObject",
        "s3:PutObjectTagging",
        "s3:ListBucket"
      ]
      resources = [
        aws_s3_bucket.bucket.arn,
        "${aws_s3_bucket.bucket.arn}/*"
      ]
    }]
    move_objects_out = [{
      actions   =  [
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      resources = [
        aws_s3_bucket.bucket.arn,
        "${aws_s3_bucket.bucket.arn}/*"
      ]
    }]
    read_write_objects = [{
      actions   =  [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ]
      resources = [
        aws_s3_bucket.bucket.arn,
        "${aws_s3_bucket.bucket.arn}/*"
      ]
    }]
    put_object = [
        {
          actions   = ["s3:PutObject"]
          resources = ["${aws_s3_bucket.bucket.arn}/*"]
        }
      ]
    put_object_tagging = [
        {
          actions   = ["s3:PutObjectTagging"]
          resources = ["${aws_s3_bucket.bucket.arn}/*"]
        }
      ]
    get_bucket_acl = [
        {
          actions = ["s3:GetBucketAcl"]
          resources = [aws_s3_bucket.bucket.arn]
        }
      ]
  }
}
