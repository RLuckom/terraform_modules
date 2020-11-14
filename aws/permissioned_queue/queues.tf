resource "aws_sqs_queue" "dead_letter" {
  count = var.make_dead_letter == true ? 1 : 0
  name                      = "${var.queue_name}_deadletter"
}

locals {
  redrive_policy = length(var.redrive_policy) == 1 ? jsonencode(var.redrive_policy[0]) : (var.make_dead_letter == true ?  jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter[0].arn
    maxReceiveCount     = var.maxReceiveCount
  }) : "")
}

resource "aws_sqs_queue" "queue" {
  name                      = var.queue_name
  redrive_policy = local.redrive_policy
}
