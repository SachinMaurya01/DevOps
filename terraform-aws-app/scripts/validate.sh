#!/usr/bin/env bash
# Validate one stage against LocalStack (or real AWS for TARGET=aws).
# Usage: ./scripts/validate.sh [network|storage|messaging|compute|all] [localstack|aws]
# Safe: read-only checks only (no apply/destroy).
set -euo pipefail

STAGE="${1:-all}"
TARGET="${2:-localstack}"
EP="http://localhost:4566"

if [ "$TARGET" = "localstack" ]; then
  export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
  EPF="--endpoint-url $EP"
else
  EPF=""
  echo "TARGET=aws: using your real AWS credentials."
fi

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; exit 1; }

echo "==> [validate:$STAGE:$TARGET] workspace=$(terraform workspace show)"
echo "==> terraform fmt -check"
terraform fmt -check -recursive || fail "run: terraform fmt -recursive"
pass "formatting clean"

echo "==> terraform validate"
terraform validate || fail "terraform validate failed"
pass "configuration valid"

case "$STAGE" in
  network|all)
    echo "==> checking network (VPC + subnets + IGW + NAT)..."
    if [ "$TARGET" = "localstack" ]; then
      aws $EPF ec2 describe-vpcs --query 'Vpcs[].[CidrBlock,State]' --output table
      aws $EPF ec2 describe-subnets --query 'Subnets[].[Tags[?Key==`Name`]|[0].Value,CidrBlock,AvailabilityZone]' --output table
      aws $EPF ec2 describe-nat-gateways --query 'NatGateways[].[State,SubnetId]' --output table
    fi
    VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
    [ -n "$VPC_ID" ] || fail "output vpc_id empty (did stage-network apply?)"
    pass "vpc_id=$VPC_ID"
    ;;
esac

case "$STAGE" in
  storage|all)
    echo "==> checking storage (S3)..."
    BUCKET=$(terraform output -raw bucket_name 2>/dev/null || echo "")
    [ -n "$BUCKET" ] || fail "output bucket_name empty (did stage-storage apply?)"
    if [ "$TARGET" = "localstack" ]; then
      aws $EPF s3 ls "s3://$BUCKET/" || fail "cannot list s3://$BUCKET"
      aws $EPF s3api get-bucket-encryption --bucket "$BUCKET" >/dev/null || echo "  WARN: no SSE config reported"
    fi
    pass "bucket=$BUCKET"
    ;;
esac

case "$STAGE" in
  messaging|all)
    echo "==> checking messaging (SQS + Lambda)..."
    QUEUE=$(terraform output -raw queue_url 2>/dev/null || echo "")
    FUNC=$(terraform output -raw lambda_function_name 2>/dev/null || echo "")
    [ -n "$QUEUE" ] || fail "output queue_url empty (did stage-messaging apply?)"
    [ -n "$FUNC" ] || fail "output lambda_function_name empty"
    if [ "$TARGET" = "localstack" ]; then
      aws $EPF sqs get-queue-attributes --queue-url "$QUEUE" --attribute-names All --output table | head -20
    fi
    pass "queue=$QUEUE func=$FUNC"
    ;;
esac

case "$STAGE" in
  compute|all)
    echo "==> checking compute (EC2)..."
    if [ "$TARGET" = "localstack" ]; then
      aws $EPF ec2 describe-instances --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,PrivateIpAddress,State.Name]' --output table
    fi
    FIP=$(terraform output -raw frontend_public_ip 2>/dev/null || echo "")
    [ -n "$FIP" ] || fail "output frontend_public_ip empty (did stage-compute apply?)"
    pass "frontend_public_ip=$FIP"
    ;;
esac

echo "==> ALL CHECKS PASSED for stage=$STAGE target=$TARGET"
