variable "name_prefix" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ami_id" {
  description = "Override the AMI. null = look up the latest Ubuntu 24.04 from Canonical."
  type        = string
  default     = null
}

variable "frontend_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "backend_instance_type" {
  type    = string
  default = "t3.small"
}

variable "root_volume_gb" {
  type    = number
  default = 20
}

variable "termination_protection" {
  description = "Block accidental deletion of the instances."
  type        = bool
  default     = false
}

variable "allowed_http_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "bucket_arn" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "queue_arn" {
  type = string
}

variable "queue_url" {
  type = string
}

variable "backend_container_image" {
  type    = string
  default = "traefik/whoami:v1.10"
}
