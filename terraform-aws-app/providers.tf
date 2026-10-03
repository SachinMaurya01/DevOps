# One provider block that works for BOTH LocalStack and real AWS.
# The switch is var.use_localstack (set in envs/localstack.tfvars).

provider "aws" {
  region = var.aws_region

  # LocalStack accepts any dummy credentials. On real AWS we pass null so the
  # provider uses your normal credentials (env vars, profile, SSO, ...).
  access_key = var.use_localstack ? "test" : null
  secret_key = var.use_localstack ? "test" : null

  # These skip checks that call real AWS APIs, which would fail offline.
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  # LocalStack serves buckets at localhost:4566/<bucket>, not <bucket>.localhost.
  s3_use_path_style = var.use_localstack

  # Point every service we use at the LocalStack edge port.
  # (dynamodb/ssm included so future backend-locking or SSM lookups also route locally.)
  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      ec2        = var.localstack_endpoint
      s3         = var.localstack_endpoint
      sqs        = var.localstack_endpoint
      lambda     = var.localstack_endpoint
      iam        = var.localstack_endpoint
      logs       = var.localstack_endpoint
      cloudwatch = var.localstack_endpoint
      cloudfront = var.localstack_endpoint
      sts        = var.localstack_endpoint
      dynamodb   = var.localstack_endpoint
      ssm        = var.localstack_endpoint
    }
  }

  # Applied to every taggable resource automatically.
  default_tags {
    tags = {
      Project     = var.project
      Environment = terraform.workspace
      ManagedBy   = "terraform"
    }
  }
}
