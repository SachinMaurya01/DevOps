variable "name_prefix" {
  type = string
}

variable "force_destroy" {
  description = "Allow 'terraform destroy' to delete a bucket that still has objects. Keep false in prod."
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "Keep old versions of overwritten or deleted objects."
  type        = bool
  default     = true
}

variable "noncurrent_version_expiry_days" {
  description = "When versioning is on, delete old versions after this many days."
  type        = number
  default     = 30
}
