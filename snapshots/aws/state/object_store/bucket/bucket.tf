module splitter_lambda {
  source = "../../../utility_functions/event_splitter"
  unique_suffix = var.unique_suffix
  action_name = "split-${local.bucket_name}"
  account_id = var.account_id
  region = var.region
  logging_config = var.utility_function_logging_config
  lambda_event_configs = var.utility_function_event_configs
  security_scope = var.security_scope
  notifications = local.lambda_notifications
}

resource "aws_s3_bucket" "bucket" {
  bucket = local.bucket_name
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_request_payment_configuration" "example" {
  bucket = aws_s3_bucket.bucket.id
  payer  = var.request_payer
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  count = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  dynamic "rule" {
    for_each = [for rule in var.lifecycle_rules : rule if rule.prefix != "" && length(rule.tags) > 0]
    content {
      id = base64sha256(jsonencode(rule.value))
      status = rule.value.enabled ? "Enabled" : "Disabled"
      filter {
        and {
          prefix = rule.value.prefix
          tags = rule.value.tags
        }
      }
      expiration {
        days = rule.value.expiration_days
      }
    }
  }

  dynamic "rule" {
    for_each = [for rule in var.lifecycle_rules : rule if rule.prefix != "" && length(rule.tags) == 0]
    content {
      id = base64sha256(jsonencode(rule.value))
      status = rule.value.enabled ? "Enabled" : "Disabled"
      filter {
        prefix = rule.value.prefix
      }
      expiration {
        days = rule.value.expiration_days
      }
    }
  }
}

resource "aws_s3_bucket_versioning" "versioning_enable" {
  count = length(var.versioning) > 0 ? 1 : 0
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = var.versioning[0].enabled ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_logging" "logging" {
  count = var.bucket_logging_config.target_bucket == "" ? 0 : 1
  bucket = aws_s3_bucket.bucket.id
  target_bucket = var.bucket_logging_config.target_bucket
  target_prefix = var.bucket_logging_config.target_prefix
}

resource "aws_s3_bucket_ownership_controls" "owner_enforced" {
  count = (var.acl == "" && length(var.grant_based_acl) == 0) ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_acl" "acl" {
  count = (var.acl == "" || length(var.grant_based_acl) > 0) ? 0 : 1
  bucket = aws_s3_bucket.bucket.id
  acl    = var.acl
}

data "aws_canonical_user_id" "current" {}

resource "aws_s3_bucket_acl" "grant_based_acl" {
  count = length(var.grant_based_acl) > 0 ? 1 : 0
  bucket = aws_s3_bucket.bucket.id
  access_control_policy {
    dynamic "grant" {
      for_each = var.grant_based_acl[0].id_grants
      content {
        grantee {
          id   = grant.value.grantee_id
          type = grant.value.grantee_type
        }
        permission = grant.value.permission
      }
    }

    dynamic "grant" {
      for_each = var.grant_based_acl[0].group_grants
      content {
        grantee {
          uri   = grant.value.grantee_uri
          type = "Group"
        }
        permission = grant.value.permission
      }
    }

    dynamic "grant" {
      for_each = var.grant_based_acl[0].owner_full_control ? [1] : []
      content {
        grantee {
          id   = data.aws_canonical_user_id.current.id
          type = "CanonicalUser"
        }
        permission = "FULL_CONTROL"
      }
    }

    owner {
      id = data.aws_canonical_user_id.current.id
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "cors" {
  count = length(var.cors_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

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
}

resource "aws_s3_bucket_website_configuration" "website" {
  count = length(var.website_configs) == 1 ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  index_document {
    suffix = var.website_configs[0].index_document
  }

  error_document {
    key = var.website_configs[0].error_document
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
  count = local.need_policy
  dynamic "statement" {
    for_each = local.grouped_prefix_object_permission_sets
    content {
      actions   = statement.value.actions
      resources   = ["${aws_s3_bucket.bucket.arn}/${statement.value.prefix == "" ? "" : "${trimsuffix(statement.value.prefix, "/")}/"}*"]
      dynamic "principals" {
        for_each = statement.value.principals
        content {
          type = principals.value.type
          identifiers = sort(principals.value.identifiers)
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
          identifiers = sort(principals.value.identifiers)
        }
      }
    }
  }

  dynamic "statement" {
    for_each = local.suffix_object_denial_sets
    content {
      actions   = statement.value.actions
      effect = "Deny"
      resources   = ["${aws_s3_bucket.bucket.arn}/*${statement.value.suffix}"]
      dynamic "principals" {
        for_each = statement.value.principals
        content {
          type = principals.value.type
          identifiers = sort(principals.value.identifiers)
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
          identifiers = sort(principals.value.identifiers)
        }
      }
    }
  }

  dynamic "statement" {
    for_each = local.conditioned_bucket_permission_sets
    content {
      actions   = statement.value.actions
      resources   = [aws_s3_bucket.bucket.arn]
      dynamic "principals" {
        for_each = statement.value.principals
        content {
          type = principals.value.type
          identifiers = sort(principals.value.identifiers)
        }
      }
      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test = condition.value.test
          variable = condition.value.variable
          values = condition.value.values
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
  count = local.need_policy
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.bucket_policy_document[0].json
}

locals {
  need_policy = var.need_policy_override ? 1 : length(var.lambda_notifications) > 0 || length(local.prefix_object_denial_sets) > 0 || length(local.grouped_prefix_object_permission_sets) > 0 || length(local.bucket_permission_sets) > 0 ? 1 : 0
  list_bucket_actions = [
    "s3:ListBucket",
    "s3:GetBucketAcl",
    "s3:GetBucketLocation"
  ]

  list_prefix_bucket_actions = [
    "s3:GetBucketAcl",
    "s3:GetBucketLocation"
  ]

  allow_billing_report_bucket_actions = [
    "s3:GetBucketAcl",
    "s3:GetBucketPolicy"
  ]

  list_bucket_action = [
    "s3:ListBucket",
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
    allow_billing_report = local.allow_billing_report_bucket_actions
    list_bucket_prefix = local.list_prefix_bucket_actions
    list_bucket_action = local.list_bucket_action
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
  suffix_object_denials = var.suffix_object_denials
  bucket_permissions = concat(
    var.bucket_permissions,
    [ for prefix_config in var.prefix_athena_query_permissions : {
      permission_type = "athena_query_execution"
      arns = prefix_config.arns
    } if length(prefix_config.arns) > 0],
    [ for prefix_config in var.prefix_list_permissions : {
      permission_type = "list_bucket_prefix"
      arns = prefix_config.arns
    } if length(prefix_config.arns) > 0],
  )
  conditioned_bucket_permissions = concat(
    [ for prefix_config in var.prefix_list_permissions : {
      permission_type = "list_bucket_action"
      conditions = [{
        test     = "StringEquals"
        variable = "s3:prefix"

        values = [
          prefix_config.prefix
        ]
      }]
      arns = prefix_config.arns
    } if length(prefix_config.arns) > 0],
    [ for prefix_config in var.prefix_list_permissions : {
      permission_type = "list_bucket_action"
      conditions = [{
        test     = "StringLike"
        variable = "s3:prefix"

        values = [
          "${prefix_config.prefix}/*"
        ]
      }]
      arns = prefix_config.arns
    } if length(prefix_config.arns) > 0]
  )
}

locals {
  object_permission_set_names = distinct(concat(
    [ for prefix_config in local.prefix_object_permissions : "${prefix_config.prefix}><${prefix_config.permission_type}"],
    [ for prefix_config in var.principal_prefix_object_permissions : "${prefix_config.prefix}><${prefix_config.permission_type}"],
  ))
  grouped_prefix_object_permission_sets = [ for set in flatten(
    [ for name in local.object_permission_set_names : {
      prefix = split("><", name)[0]
      actions = local.object_permission_set_actions[split("><", name)[1]]
      principals = concat( length(flatten([for prefix_config in local.prefix_object_permissions : prefix_config.arns if prefix_config.prefix == split("><", name)[0] && prefix_config.permission_type == split("><", name)[1]])) > 0 ? [
        {
          type = "AWS"
          identifiers = distinct(flatten([for prefix_config in local.prefix_object_permissions : prefix_config.arns if prefix_config.prefix == split("><", name)[0] && prefix_config.permission_type == split("><", name)[1]]))
        }
      ] : [], flatten([ for prefix_config in var.principal_prefix_object_permissions : prefix_config.prefix == split("><", name)[0] && prefix_config.permission_type == split("><", name)[1] ? prefix_config.principals : []])
    )}]
  ) : set if length(set.principals) > 0]
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
  suffix_object_denial_sets = concat(
    [ for suffix_config in local.suffix_object_denials : {
      suffix = suffix_config.suffix
      actions = local.object_permission_set_actions[suffix_config.permission_type]
      principals = [
        {
          type = "AWS"
          identifiers = suffix_config.arns 
        }
      ]
    } if length(suffix_config.arns) > 0],
    [ for suffix_config in var.principal_suffix_object_denials : {
      suffix = suffix_config.suffix
      actions = local.object_permission_set_actions[suffix_config.permission_type]
      principals = suffix_config.principals
    } if length(suffix_config.principals) > 0],
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

  conditioned_bucket_permission_sets = concat(
    [ for bucket_config in local.conditioned_bucket_permissions : {
      actions = local.bucket_permission_set_actions[bucket_config.permission_type]
      principals = [
        {
          type = "AWS"
          identifiers = bucket_config.arns 
        }
      ]
      conditions = bucket_config.conditions
    } if length(bucket_config.arns) > 0],
    []
  )
}
