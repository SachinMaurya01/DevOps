output "bucket_id" {
  description = "Bucket name."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "bucket_regional_domain_name" {
  description = "Used as the CloudFront origin."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
