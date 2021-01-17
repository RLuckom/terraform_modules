resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket
  acl = var.acl
  request_payer = var.request_payer
  dynamic "website" {
    for_each = var.website_configs
    content {
      index_document = website.value.index_document
      error_document = website.value.error_document
    }
  }

  dynamic "versioning" {
    for_each = var.versioning
    content {
      enabled = versioning.value.enabled
    }
  }

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_origins = cors_rule.value.allowed_origins
      allowed_methods = cors_rule.value.allowed_methods
      expose_headers = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules
    content {
      id = lifecycle_rule.value.id
      prefix = lifecycle_rule.value.prefix
      tags = lifecycle_rule.value.tags
      enabled = lifecycle_rule.value.enabled
      expiration {
        days = lifecycle_rule.value.expiration_days
      }
    }
  }
}

resource "aws_lambda_permission" "allow_caller" {
  count = length(var.lambda_notifications)
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_notifications[count.index].lambda_name
  principal     = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  count = length(var.lambda_notifications) == 0 ? 0 : 1
  bucket = aws_s3_bucket.bucket.id

  dynamic "lambda_function" {
    for_each = var.lambda_notifications
    content {
      lambda_function_arn = lambda_function.value.lambda_arn
      events              = lambda_function.value.events
      filter_prefix       = lambda_function.value.filter_prefix
      filter_suffix       = lambda_function.value.filter_suffix
    }
  }
}

data "aws_iam_policy_document" "bucket_policy_document" {
  count = local.need_policy ? 1 : 0
  dynamic "statement" {
    for_each = var.object_policy_statements
    content {
      actions   = statement.value.actions
      resources   = ["${aws_s3_bucket.bucket.arn}/${statement.value.prefix == "" ? "" : "${statement.value.prefix}/"}*"]
      dynamic "principals" {
        for_each = statement.value.principals
        content {
          type = principals.value.type
          identifiers = principals.value.identifiers
        }
      }
    }
  }

  dynamic "statement" {
    for_each = var.bucket_policy_statements
    content {
      actions   = statement.value.actions
      resources   = [aws_s3_bucket.bucket.arn]
      dynamic "principals" {
        for_each = statement.value.principals
        content {
          type = principals.value.type
          identifiers = principals.value.identifiers
        }
      }
    }
  }

  dynamic "statement" {
    for_each = var.lambda_notifications
    content {
      actions   = local.permission_sets[statement.value.permission_type][0].actions
      resources = [
        "${aws_s3_bucket.bucket.arn}/${statement.value.filter_prefix}*"
      ]
      principals {
        type = "AWS"
        identifiers = [statement.value.lambda_role_arn]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  count = local.need_policy ? 1 : 0
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.bucket_policy_document[0].json
}

locals {
  permission_sets = {
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
    read_and_tag_known = [{
      actions   =  [
        "s3:GetObject",
        "s3:PutObjectTagging",
      ]
      resources = [
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
    move_known_object_out = [{
      actions   =  [
        "s3:GetObject",
        "s3:DeleteObject",
      ]
      resources = [
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
    delete_object = [
      {
        actions   = ["s3:DeleteObject"]
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
