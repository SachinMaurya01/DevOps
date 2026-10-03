variable "project" {
  description = "Short project name. Used as a prefix for every resource name."
  type        = string
  default     = "myapp"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project))
    error_message = "Use 2-21 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "use_localstack" {
  description = "true = send all API calls to LocalStack instead of real AWS."
  type        = bool
  default     = false
}

variable "localstack_endpoint" {
  description = "LocalStack edge URL."
  type        = string
  default     = "http://localhost:4566"
}

variable "localstack_ami_id" {
  description = "Fake AMI used only when use_localstack = true. LocalStack has no real Ubuntu catalogue, so we pin one of its built-in fake IDs. If EC2 planning fails with InvalidAMIID, discover a valid one with: aws --endpoint-url http://localhost:4566 ec2 describe-images --query 'Images[].ImageId' --output table"
  type        = string
  default     = "ami-ff0fea8310f3"
}

variable "enable_cloudfront" {
  description = "Create the CloudFront distribution in front of S3. Turn off if your LocalStack plan does not include CloudFront."
  type        = bool
  default     = true
}

variable "allowed_http_cidrs" {
  description = "Who may reach the frontend on ports 80/443. Restrict this for internal apps."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "backend_container_image" {
  description = "Docker image the backend instance runs. The default is a tiny demo server; replace with your own image."
  type        = string
  default     = "traefik/whoami:v1.10"
}
