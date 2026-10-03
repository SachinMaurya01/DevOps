variable "aws_region" {
  description = "AWS region (LocalStack emulates this region)"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "S3 bucket name (lowercase, hyphens only, globally unique)"
  type        = string
  default     = "static-website-88392"
}

variable "localstack_endpoint" {
  description = "LocalStack edge endpoint"
  type        = string
  default     = "http://localhost:4566"
}
