module "lambda_role" {
  source = "github.com/RLuckom/terraform_modules//aws/permissioned_role"
  role_name = "${local.scoped_lambda_name}-lambda"
  account_id = var.account_id
  unique_suffix = var.unique_suffix
  role_policy = concat(local.lambda_destinations, var.self_invoke.allowed ? local.lambda_invoke : [], var.deny_cloudwatch ? [] : var.log_writer_policy, var.lambda_details.policy_statements)
  principals = [{
    type = "Service"
    identifiers = sort(var.role_service_principal_ids)
  }]
}

locals {
  lambda_arn = "arn:aws:lambda:${var.region}:${var.account_id}:function:${local.scoped_lambda_name}"
  lambda_invoke = concat([{
    actions   =  [
      "lambda:InvokeFunction"
    ]
    resources = [
      local.lambda_arn
    ]
  }])
  lambda_destinations = concat(
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
  local_source_files = var.local_source_directory == null ? [] : tolist(fileset(var.local_source_directory, "**"))
  source_contents = concat(var.source_contents, 
  var.local_source_directory == null ? [] :
  [for n in range(length(local.local_source_files)) :
  {
    file_contents = data.local_file.local_sources[n].content
    file_name = local.local_source_files[n]
  }])
  state_hash = sha1(jsonencode({
    source_contents = local.source_contents
    environmemt = var.environment_var_map
  }))
}

data local_file local_sources {
  count = length(local.local_source_files)
  filename = "${var.local_source_directory}/${local.local_source_files[count.index]}"
}

data "archive_file" "deployment_package" {
  count = length(local.source_contents) == 0 ? 0 : 1
  type        = "zip"
  output_path = local.deployment_package_local_path

  dynamic "source" {
    for_each = local.source_contents
    content {
      content  = source.value.file_contents
      filename = source.value.file_name
    }
  }
}

locals {
  s3_deployment = length(var.lambda_event_configs) > 0 && var.source_bucket != ""
  need_event_config = length(var.source_contents) > 0 &&  length(var.lambda_event_configs) > 0
}

resource "aws_lambda_function_event_invoke_config" "function_notifications" {
  count = local.need_event_config ? 1 : 0
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

resource "aws_s3_object" "deployment_package_zip" {
  count = local.s3_deployment ? 1 : 0
  bucket = var.source_bucket
  key    = local.deployment_package_key
  source = local.deployment_package_local_path

  etag = data.archive_file.deployment_package[0].output_md5
}

resource "aws_lambda_function" "lambda" {
  function_name = local.scoped_lambda_name
  publish = var.publish
  runtime = local.runtime
  architectures = [local.architecture]
  s3_bucket = var.preuploaded_source.supplied ? var.preuploaded_source.bucket : (local.s3_deployment ? var.source_bucket : null)
  s3_key = var.preuploaded_source.supplied ? var.preuploaded_source.path : (local.s3_deployment ? local.deployment_package_key : null)
  filename = (local.s3_deployment || var.preuploaded_source.supplied) ? null : local.deployment_package_local_path
  role          = module.lambda_role.role.arn
  handler       = var.handler
  layers = var.layers.*.arn
	timeout = var.timeout_secs
  source_code_hash = length(data.archive_file.deployment_package) > 0 ? data.archive_file.deployment_package[0].output_base64sha256 : null
  reserved_concurrent_executions = var.self_invoke.allowed ? var.self_invoke.concurrent_executions : var.reserved_concurrent_executions
	memory_size = var.mem_mb

  dynamic "environment" {
    for_each = length(values(var.environment_var_map)) > 0 ? [1] : []
    content {
      variables = var.environment_var_map
    }
  }
  depends_on = [aws_s3_object.deployment_package_zip, module.lambda_role]
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
	name              = "/aws/lambda/${local.scoped_lambda_name}"
	retention_in_days = var.log_retention_period
}

locals {
  callers = concat(
    var.invoking_principals,
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

resource "aws_lambda_permission" "allow_roles" {
  count = length(var.invoking_roles)
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = var.invoking_roles[count.index]
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
