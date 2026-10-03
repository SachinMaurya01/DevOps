output "bucket_name" {
  description = "Created S3 bucket name"
  value       = aws_s3_bucket.site.id
}

output "website_endpoint" {
  description = "S3 website endpoint (works on real AWS; on LocalStack use localstack URLs below)"
  value       = aws_s3_bucket_website_configuration.site.website_endpoint
}

output "localstack_s3_url" {
  description = "Direct S3 object URL via LocalStack (path-style)"
  value       = "http://localhost:4566/${aws_s3_bucket.site.id}/index.html"
}

output "localstack_website_url" {
  description = "Website-style URL via LocalStack"
  value       = "http://${aws_s3_bucket.site.id}.s3-website.localhost.localstack.cloud:4566/index.html"
}
