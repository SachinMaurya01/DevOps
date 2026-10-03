output "queue_url" {
  value = aws_sqs_queue.jobs.id
}

output "queue_arn" {
  value = aws_sqs_queue.jobs.arn
}

output "dlq_url" {
  value = aws_sqs_queue.dlq.id
}

output "lambda_function_name" {
  value = aws_lambda_function.processor.function_name
}
