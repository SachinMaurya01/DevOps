output "environment" {
  description = "Active workspace / environment."
  value       = terraform.workspace
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "nat_public_ips" {
  description = "Outbound IPs of your private instances (useful for allow-lists)."
  value       = module.network.nat_public_ips
}

output "frontend_public_ip" {
  value = module.compute.frontend_public_ip
}

output "app_url" {
  value = "http://${module.compute.frontend_public_ip}"
}

output "backend_private_ip" {
  value = module.compute.backend_private_ip
}

output "bucket_name" {
  value = module.storage.bucket_id
}

output "queue_url" {
  value = module.messaging.queue_url
}

output "dlq_url" {
  value = module.messaging.dlq_url
}

output "lambda_function_name" {
  value = module.messaging.lambda_function_name
}

output "cloudfront_domain" {
  description = "null when enable_cloudfront = false."
  value       = module.cdn.domain_name
}
