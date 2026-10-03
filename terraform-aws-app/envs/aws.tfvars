# Use with:  terraform plan -var-file=envs/aws.tfvars
# Real AWS. Costs money (NAT gateways, EC2, CloudFront) - destroy dev when done.
use_localstack    = false
aws_region        = "us-east-1"
enable_cloudfront = true

# Tighten this for anything that is not a public website.
allowed_http_cidrs = ["0.0.0.0/0"]
