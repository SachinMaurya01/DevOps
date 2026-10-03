# Async pipeline:
#
#   file uploaded to S3 (uploads/...)
#        |  S3 event notification
#        v
#   SQS queue  --(after N failed attempts)-->  dead-letter queue
#        |  event source mapping
#        v
#   Lambda (modules/messaging/lambda_src/handler.py)
#
# The backend can also push its own jobs straight onto the queue.

locals {
  function_name = "${var.name_prefix}-processor"
  log_group     = "/aws/lambda/${local.function_name}"
}

# ---- Queues ----------------------------------------------------------------

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name_prefix}-jobs-dlq"
  message_retention_seconds = 1209600 # 14 days to investigate failures
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "jobs" {
  name = "${var.name_prefix}-jobs"

  # AWS recommends visibility timeout >= 6x the Lambda timeout.
  visibility_timeout_seconds = var.lambda_timeout_s * 6
  message_retention_seconds  = 345600 # 4 days
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}

# Allow the S3 service (and only OUR bucket) to put messages on the queue.
resource "aws_sqs_queue_policy" "allow_s3" {
  queue_url = aws_sqs_queue.jobs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowS3BucketToSendMessages"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.jobs.arn
      Condition = { ArnEquals = { "aws:SourceArn" = var.bucket_arn } }
    }]
  })
}

resource "aws_s3_bucket_notification" "uploads" {
  bucket = var.bucket_id

  queue {
    queue_arn     = aws_sqs_queue.jobs.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = var.upload_prefix
  }

  depends_on = [aws_sqs_queue_policy.allow_s3]
}

# ---- Lambda ----------------------------------------------------------------

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src"
  output_path = "${path.module}/.build/processor.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = local.log_group
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "lambda" {
  name = "${local.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Least privilege: write its own logs, read from its own queue. Nothing else.
resource "aws_iam_role_policy" "lambda" {
  name = "${local.function_name}-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "WriteLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      },
      {
        Sid      = "ConsumeQueue"
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.jobs.arn
      }
    ]
  })
}

resource "aws_lambda_function" "processor" {
  function_name = local.function_name
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_s

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda, aws_iam_role_policy.lambda]
}

resource "aws_lambda_event_source_mapping" "jobs" {
  event_source_arn = aws_sqs_queue.jobs.arn
  function_name    = aws_lambda_function.processor.arn
  batch_size       = 10

  # Only the messages that failed go back to the queue, not the whole batch.
  function_response_types = ["ReportBatchItemFailures"]
}
