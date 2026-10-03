variable "enable" {
  description = "Set false to skip CloudFront entirely (e.g. LocalStack free tier)."
  type        = bool
  default     = true
}

variable "name_prefix" {
  type = string
}

variable "bucket_regional_domain_name" {
  type = string
}

variable "price_class" {
  description = "PriceClass_100 (cheapest, fewest edges), PriceClass_200 or PriceClass_All."
  type        = string
  default     = "PriceClass_100"
}
