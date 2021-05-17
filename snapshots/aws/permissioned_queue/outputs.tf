output "queue" {
  value = aws_sqs_queue.queue
}

output "deadletter" {
  value = aws_sqs_queue.dead_letter
}

output "permission_sets" {
  value = {
    send_message = [
      {
        actions = ["sqs:sendMessage"]
        resources = [aws_sqs_queue.queue.arn]
      }
    ]
    lambda_receive = [
      {
        actions = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        resources = [aws_sqs_queue.queue.arn]
      }
    ]
  }
}
