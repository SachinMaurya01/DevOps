#!/usr/bin/env bash
# Proves the async pipeline works on LocalStack:
#   upload a file -> S3 event -> SQS -> Lambda -> log line
# Run from the project root after 'make apply' in the dev workspace.
set -euo pipefail

export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
EP="--endpoint-url http://localhost:4566"

BUCKET=$(terraform output -raw bucket_name)
FUNC=$(terraform output -raw lambda_function_name)
QUEUE=$(terraform output -raw queue_url)
DLQ=$(terraform output -raw dlq_url)

echo "==> Uploading a test file to s3://$BUCKET/uploads/"
echo "hello from verify.sh at $(date -u +%FT%TZ)" > /tmp/verify.txt
aws $EP s3 cp /tmp/verify.txt "s3://$BUCKET/uploads/verify-$(date +%s).txt"

echo "==> Waiting for SQS -> Lambda (up to 60s)..."
for _ in $(seq 1 12); do
  sleep 5
  if aws $EP logs filter-log-events --log-group-name "/aws/lambda/$FUNC" \
       --filter-pattern "New upload" --query 'events[].message' --output text 2>/dev/null | grep -q "New upload"; then
    echo "==> SUCCESS - Lambda processed the upload:"
    aws $EP logs filter-log-events --log-group-name "/aws/lambda/$FUNC" \
      --filter-pattern "New upload" --query 'events[-1].message' --output text
    exit 0
  fi
done

echo "==> No Lambda log line yet. Queue depth and dead-letter queue:"
aws $EP sqs get-queue-attributes --queue-url "$QUEUE" --attribute-names ApproximateNumberOfMessages
aws $EP sqs get-queue-attributes --queue-url "$DLQ" --attribute-names ApproximateNumberOfMessages
echo "Tip: docker logs localstack | tail -50"
exit 1
