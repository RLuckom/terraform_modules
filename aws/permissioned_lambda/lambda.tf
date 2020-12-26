module "lambda_role" {
  source = "../permissioned_role"
  role_name = "${local.scoped_lambda_name}-lambda"
  role_policy = concat(length(local.lambda_invoke) > 0 ? local.lambda_invoke : [], var.deny_cloudwatch ? [] : var.log_writer_policy, var.lambda_details.policy_statements)
  principals = [{
    type = "Service"
    identifiers = ["lambda.amazonaws.com"]
  }]
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  lambda_invoke = concat([{
    actions   =  [
      "lambda:InvokeFunction"
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${local.scoped_lambda_name}"
    ]
  }],  
  length(var.lambda_event_configs) > 0 ? (length(var.lambda_event_configs[0].on_success) > 0 ? [{
    actions   =  [
      "lambda:InvokeFunction"
    ]
    resources = [
       var.lambda_event_configs[0].on_success[0].function_arn
    ]
  }] : []) : [],
  length(var.lambda_event_configs) > 0 ? (length(var.lambda_event_configs[0].on_failure) > 0 ? [{
    actions   =  [
      "lambda:InvokeFunction"
    ]
    resources = [
       var.lambda_event_configs[0].on_failure[0].function_arn
    ]
  }] : []) : [])
}

data "archive_file" "deployment_package" {
  count = length(var.source_contents) == 0 ? 0 : 1
  type        = "zip"
  output_path = local.deployment_package_local_path

  dynamic "source" {
    for_each = var.source_contents
    content {
      content  = source.value.file_contents
      filename = source.value.file_name
    }
  }
}

resource "aws_lambda_function_event_invoke_config" "function_notifications" {
  count = length(var.lambda_event_configs) == 0 ? 0 : 1
  function_name    = aws_lambda_function.lambda.arn
  maximum_event_age_in_seconds = var.lambda_event_configs[0].maximum_event_age_in_seconds
  maximum_retry_attempts = var.lambda_event_configs[0].maximum_retry_attempts

  dynamic "destination_config" {
    for_each = var.lambda_event_configs
    content {
      dynamic "on_failure" {
        for_each = destination_config.value.on_failure
        content {
          destination = on_failure.value.function_arn
        }
      }
      dynamic "on_success" {
        for_each = destination_config.value.on_success
        content {
          destination = on_success.value.function_arn
        }
      }
    }
  }
}

resource "aws_s3_bucket_object" "deployment_package_zip" {
  count = length(var.source_contents) == 0 ? 0 : 1
  bucket = var.lambda_details.bucket
  key    = local.deployment_package_key
  source = local.deployment_package_local_path

  etag = data.archive_file.deployment_package[0].output_md5
}

resource "aws_lambda_function" "lambda" {
  function_name = local.scoped_lambda_name
  s3_bucket = var.lambda_details.bucket
	s3_key = local.deployment_package_key
  role          = module.lambda_role.role.arn
  handler       = var.handler
  layers = var.layers
	timeout = var.timeout_secs
  source_code_hash = length(data.archive_file.deployment_package) > 0 ? data.archive_file.deployment_package[0].output_base64sha256 : null
  reserved_concurrent_executions = var.self_invoke.allowed ? var.self_invoke.concurrent_executions : var.reserved_concurrent_executions
	memory_size = var.mem_mb

  runtime = "nodejs12.x"
  environment {
    variables = var.environment_var_map
  }
  depends_on = [aws_s3_bucket_object.deployment_package_zip]
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
	name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
	retention_in_days = var.log_retention_period
}

data "aws_s3_bucket" "trigger_bucket" {
  count = length(var.bucket_notifications)
  bucket = var.bucket_notifications[count.index].bucket
}

locals {
  callers = concat(
    var.invoking_principals,
    [ for i, notification in var.bucket_notifications: {
      service = "s3.amazonaws.com"
      source_arn = data.aws_s3_bucket.trigger_bucket[i].arn
    }],
    [ for i, notification in var.cron_notifications: {
      service = "events.amazonaws.com"
      source_arn = aws_cloudwatch_event_rule.lambda_schedule[i].arn
    }],
    [ for event_source in var.queue_event_sources: {
      service = "sqs.amazonaws.com"
      source_arn = event_source.arn
    }]
  )
}

resource "aws_lambda_permission" "allow_caller" {
  count = length(local.callers)
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = local.callers[count.index].service
  source_arn = local.callers[count.index].source_arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  count = length(var.bucket_notifications)
  bucket = var.bucket_notifications[count.index].bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda.arn
    events              = var.bucket_notifications[count.index].events
    filter_prefix       = var.bucket_notifications[count.index].filter_prefix
    filter_suffix       = var.bucket_notifications[count.index].filter_suffix
  }
}

resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  count = length(var.cron_notifications)
  schedule_expression = var.cron_notifications[count.index].period_expression
}

resource "aws_cloudwatch_event_target" "lambda_evt_target" {
  count = length(var.cron_notifications)
  rule = aws_cloudwatch_event_rule.lambda_schedule[count.index].name
  arn = aws_lambda_function.lambda.arn
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  count = length(var.queue_event_sources)
  event_source_arn = var.queue_event_sources[count.index].arn
  function_name    = aws_lambda_function.lambda.arn
  batch_size = var.queue_event_sources[count.index].batch_size
}
