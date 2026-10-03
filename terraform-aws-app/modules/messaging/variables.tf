variable "name_prefix" {
  type = string
}

variable "bucket_id" {
  description = "Bucket whose uploads trigger processing."
  type        = string
}

variable "bucket_arn" {
  type = string
}

variable "upload_prefix" {
  description = "Only objects under this key prefix create queue messages."
  type        = string
  default     = "uploads/"
}

variable "lambda_memory_mb" {
  type    = number
  default = 128
}

variable "lambda_timeout_s" {
  type    = number
  default = 30
}

variable "max_receive_count" {
  description = "Delivery attempts before a message moves to the dead-letter queue."
  type        = number
  default     = 3
}

variable "log_retention_days" {
  type    = number
  default = 14
}
