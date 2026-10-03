output "domain_name" {
  description = "d123.cloudfront.net, or null when disabled."
  value       = try(aws_cloudfront_distribution.this[0].domain_name, null)
}

output "distribution_arn" {
  value = try(aws_cloudfront_distribution.this[0].arn, null)
}
