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
      resources   = ["${aws_s3_bucket.bucket.arn}/*"]
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
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  count = local.need_policy ? 1 : 0
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.bucket_policy_document[0].json
}
