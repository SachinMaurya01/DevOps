# The bucket policy lives in the root module because it combines two things:
#   1. a rule from the storage side (refuse plain-HTTP requests)
#   2. a rule from the CDN side (let CloudFront read objects)
# A bucket can only have ONE policy, so we build it in one place.

locals {
  deny_insecure_transport = {
    Sid       = "DenyInsecureTransport"
    Effect    = "Deny"
    Principal = "*"
    Action    = "s3:*"
    Resource  = [module.storage.bucket_arn, "${module.storage.bucket_arn}/*"]
    Condition = { Bool = { "aws:SecureTransport" = "false" } }
  }

  allow_cloudfront_read = {
    Sid       = "AllowCloudFrontServicePrincipalRead"
    Effect    = "Allow"
    Principal = { Service = "cloudfront.amazonaws.com" }
    Action    = "s3:GetObject"
    Resource  = "${module.storage.bucket_arn}/*"
    Condition = { StringEquals = { "AWS:SourceArn" = module.cdn.distribution_arn } }
  }

  bucket_policy_statements = concat(
    # LocalStack speaks plain HTTP, so we only enforce TLS on real AWS.
    var.use_localstack ? [] : [local.deny_insecure_transport],
    var.enable_cloudfront ? [local.allow_cloudfront_read] : []
  )
}

resource "aws_s3_bucket_policy" "files" {
  count  = length(local.bucket_policy_statements) > 0 ? 1 : 0
  bucket = module.storage.bucket_id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.bucket_policy_statements
  })
}
