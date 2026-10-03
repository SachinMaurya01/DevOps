# CloudFront in front of the PRIVATE S3 bucket.
# Origin Access Control (OAC) lets CloudFront sign requests to S3, so the
# bucket itself never has to be public. The matching bucket policy is in the
# root module (bucket_policy.tf).

resource "aws_cloudfront_origin_access_control" "this" {
  count = var.enable ? 1 : 0

  name                              = "${var.name_prefix}-oac"
  description                       = "OAC for ${var.name_prefix} files bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  count = var.enable ? 1 : 0

  enabled         = true
  is_ipv6_enabled = true
  comment         = "${var.name_prefix} files"
  price_class     = var.price_class

  origin {
    domain_name              = var.bucket_regional_domain_name
    origin_id                = "s3-files"
    origin_access_control_id = aws_cloudfront_origin_access_control.this[0].id
  }

  default_cache_behavior {
    target_origin_id       = "s3-files"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # AWS-managed "CachingOptimized" policy.
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Uses the default *.cloudfront.net certificate. For your own domain add an
  # ACM certificate (must be in us-east-1) and 'aliases'.
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
