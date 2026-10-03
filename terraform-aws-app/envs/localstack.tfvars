# Use with:  terraform plan -var-file=envs/localstack.tfvars
use_localstack      = true
localstack_endpoint = "http://localhost:4566"
aws_region          = "us-east-1"

# CloudFront is not part of LocalStack's free offering at the time of writing.
# Check LocalStack's service coverage page; set to true if your plan has it.
enable_cloudfront = false
