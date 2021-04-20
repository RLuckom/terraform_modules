module splitter_lambda {
  source = "github.com/RLuckom/terraform_modules//aws/utility_functions/event_splitter"
  action_name = "split-${var.name}"
  logging_config = var.utility_function_logging_config
  lambda_event_configs = var.utility_function_event_configs
  security_scope = var.security_scope
  notifications = local.lambda_notifications
}

resource "aws_s3_bucket" "bucket" {
  bucket = var.name
  acl = var.acl
  request_payer = var.request_payer
  force_destroy = var.force_destroy

  dynamic "logging" {
    for_each = var.bucket_logging_config.target_bucket == "" ? [] : [1]
    content {
      target_bucket = var.bucket_logging_config.target_bucket
      target_prefix = var.bucket_logging_config.target_prefix
    }
  }

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
  count = length(local.lambda_invoke_permissions_needed)
  action        = "lambda:InvokeFunction"
  function_name = local.lambda_invoke_permissions_needed[count.index]
  principal     = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  count = length(local.effective_notifications) == 0 ? 0 : 1
  bucket = aws_s3_bucket.bucket.id

  dynamic "lambda_function" {
    for_each = local.effective_notifications
    content {
      lambda_function_arn = lambda_function.value.lambda_arn
      events              = lambda_function.value.events
      filter_prefix       = lambda_function.value.filter_prefix
      filter_suffix       = lambda_function.value.filter_suffix
    }
  }
}

data aws_iam_policy_document bucket_policy_document {
  count = length(var.lambda_notifications) > 0 || length(local.prefix_object_denial_sets) > 0 || length(local.prefix_object_permission_sets) > 0 || length(local.bucket_permission_sets) > 0 ? 1 : 0
  dynamic "statement" {
    for_each = local.prefix_object_permission_sets
    content {
      actions   = statement.value.actions
      resources   = ["${aws_s3_bucket.bucket.arn}/${statement.value.prefix == "" ? "" : "${trimsuffix(statement.value.prefix, "/")}/"}*"]
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
    for_each = local.prefix_object_denial_sets
    content {
      actions   = statement.value.actions
      effect = "Deny"
      resources   = ["${aws_s3_bucket.bucket.arn}/${statement.value.prefix == "" ? "" : "${trimsuffix(statement.value.prefix, "/")}/"}*"]
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
    for_each = local.bucket_permission_sets
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
      actions   = concat(
        lookup(local.object_permission_set_actions, statement.value.permission_type, []),
        lookup(local.bucket_permission_set_actions, statement.value.permission_type, [])
      )
      resources = concat(
        length(lookup(local.object_permission_set_actions, statement.value.permission_type, [])) > 0 ? ["${aws_s3_bucket.bucket.arn}/${trimsuffix(statement.value.filter_prefix, "/")}${statement.value.filter_prefix == "" ? "" : "/"}*"] : [],
        length(lookup(local.bucket_permission_set_actions, statement.value.permission_type, [])) > 0 ? [aws_s3_bucket.bucket.arn] : []
      )
      principals {
        type = "AWS"
        identifiers = [statement.value.lambda_role_arn]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  count = length(var.lambda_notifications) > 0 || length(local.prefix_object_denial_sets) > 0 || length(local.prefix_object_permission_sets) > 0 || length(local.bucket_permission_sets) > 0 ? 1 : 0
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.bucket_policy_document[0].json
}

locals {
  list_bucket_actions = [
    "s3:ListBucket",
    "s3:GetBucketAcl",
    "s3:GetBucketLocation"
  ]

  put_object_actions = [
    "s3:PutObject",
    "s3:AbortMultipartUpload",
    "s3:PutObjectTagging",
    "s3:ListMultipartUploadParts"
  ]

  read_known_object_actions = [
    "s3:GetObject",
    "s3:GetObjectTagging",
    "s3:GetObjectVersion",
  ]

  tag_known_object_actions = [
    "s3:PutObjectTagging",
  ]

  delete_known_object_actions = [
    "s3:DeleteObject",
  ]

  move_known_object_out_actions = concat(
    local.read_known_object_actions,
    local.delete_known_object_actions
  )

  read_and_tag_known_actions =  concat(
    local.read_known_object_actions,
    local.tag_known_object_actions,
  )

  read_write_known_objects_actions = concat(
    local.read_known_object_actions,
    local.put_object_actions
  )

  bucket_permission_set_actions = {
    list_bucket = local.list_bucket_actions
    athena_query_execution = local.list_bucket_actions
  }

  object_permission_set_actions = {
    read_known_objects = local.read_known_object_actions
    athena_query_execution =  local.read_known_object_actions
    read_and_tag = local.read_and_tag_known_actions
    read_and_tag_known = local.read_and_tag_known_actions
    move_objects_out = local.move_known_object_out_actions
    move_known_objects_out = local.move_known_object_out_actions
    read_write_objects = local.read_write_known_objects_actions
    put_object = local.put_object_actions
    delete_object = local.delete_known_object_actions
    put_object_tagging = local.tag_known_object_actions
  }
}

locals {
  prefix_object_permissions = concat(
    var.prefix_object_permissions,
    concat(
      [ for prefix_config in var.prefix_athena_query_permissions : {
        prefix = prefix_config.log_storage_prefix
        permission_type = "athena_query_execution"
        arns = prefix_config.arns
      } if length(prefix_config.arns) > 0
    ],
    [ for prefix_config in var.prefix_athena_query_permissions : {
      prefix = prefix_config.result_prefix
      permission_type = "read_write_objects"
      arns = prefix_config.arns
    } if length(prefix_config.arns) > 0
  ])
  )
  prefix_object_denials = var.prefix_object_denials
  bucket_permissions = concat(
    var.bucket_permissions,
    [ for prefix_config in var.prefix_athena_query_permissions : {
      permission_type = "athena_query_execution"
      arns = prefix_config.arns
    } if length(prefix_config.arns) > 0],
  )
}

locals {
  prefix_object_permission_sets = concat(
    [ for prefix_config in local.prefix_object_permissions : {
      prefix = prefix_config.prefix
      actions = local.object_permission_set_actions[prefix_config.permission_type]
      principals = [
        {
          type = "AWS"
          identifiers = prefix_config.arns 
        }
      ]
    } if length(prefix_config.arns) > 0],
    [ for prefix_config in var.principal_prefix_object_permissions : {
      prefix = prefix_config.prefix
      actions = local.object_permission_set_actions[prefix_config.permission_type]
      principals = prefix_config.principals
    } if length(prefix_config.principals) > 0],
  )
  prefix_object_denial_sets = concat(
    [ for prefix_config in local.prefix_object_denials : {
      prefix = prefix_config.prefix
      actions = local.object_permission_set_actions[prefix_config.permission_type]
      principals = [
        {
          type = "AWS"
          identifiers = prefix_config.arns 
        }
      ]
    } if length(prefix_config.arns) > 0],
    [ for prefix_config in var.principal_prefix_object_denials : {
      prefix = prefix_config.prefix
      actions = local.object_permission_set_actions[prefix_config.permission_type]
      principals = prefix_config.principals
    } if length(prefix_config.principals) > 0],
  )
  bucket_permission_sets = concat(
    [ for bucket_config in local.bucket_permissions : {
      actions = local.bucket_permission_set_actions[bucket_config.permission_type]
      principals = [
        {
          type = "AWS"
          identifiers = bucket_config.arns 
        }
      ]
    } if length(bucket_config.arns) > 0],
    [ for bucket_config in var.principal_bucket_permissions : {
      actions = local.bucket_permission_set_actions[bucket_config.permission_type]
      principals = bucket_config.principals
    } if length(bucket_config.principals) > 0],
  )
}
