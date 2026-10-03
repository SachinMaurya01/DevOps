variable "name_prefix" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_cidr" {
  description = "CIDR block for the whole VPC, e.g. 10.10.0.0/16."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "az_count" {
  description = "How many Availability Zones to spread subnets across (2 or 3)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = "true = one shared NAT (cheap). false = one NAT per AZ (resilient)."
  type        = bool
  default     = true
}

variable "enable_s3_gateway_endpoint" {
  description = "Free S3 route from private subnets that bypasses the NAT (saves data-transfer cost)."
  type        = bool
  default     = true
}
