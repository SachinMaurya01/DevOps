locals {
  # The workspace name IS the environment name: dev, staging or prod.
  env         = terraform.workspace
  name_prefix = "${var.project}-${local.env}"

  # Everything that differs between environments lives in this one map.
  env_config = {
    dev = {
      vpc_cidr              = "10.10.0.0/16"
      az_count              = 2
      single_nat_gateway    = true # one NAT = cheaper, less resilient
      frontend_instance     = "t3.micro"
      backend_instance      = "t3.small"
      root_volume_gb        = 20
      termination_protect   = false
      bucket_force_destroy  = true # lets 'terraform destroy' empty the bucket
      bucket_versioning     = false
      cloudfront_price      = "PriceClass_100"
      lambda_memory_mb      = 128
      lambda_timeout_s      = 30
      log_retention_days    = 7
      sqs_max_receive_count = 3
    }
    staging = {
      vpc_cidr              = "10.20.0.0/16"
      az_count              = 2
      single_nat_gateway    = true
      frontend_instance     = "t3.small"
      backend_instance      = "t3.medium"
      root_volume_gb        = 30
      termination_protect   = false
      bucket_force_destroy  = true
      bucket_versioning     = true
      cloudfront_price      = "PriceClass_100"
      lambda_memory_mb      = 256
      lambda_timeout_s      = 30
      log_retention_days    = 30
      sqs_max_receive_count = 3
    }
    prod = {
      vpc_cidr              = "10.30.0.0/16"
      az_count              = 2
      single_nat_gateway    = false # one NAT per AZ survives an AZ outage
      frontend_instance     = "t3.medium"
      backend_instance      = "t3.large"
      root_volume_gb        = 50
      termination_protect   = true
      bucket_force_destroy  = false # never auto-delete production data
      bucket_versioning     = true
      cloudfront_price      = "PriceClass_All"
      lambda_memory_mb      = 512
      lambda_timeout_s      = 60
      log_retention_days    = 90
      sqs_max_receive_count = 5
    }
  }

  # lookup() with a fallback lets the guard below print a friendly error
  # instead of Terraform's cryptic "invalid index" message.
  config = lookup(local.env_config, local.env, local.env_config["dev"])

  # In LocalStack there is no real Ubuntu image catalogue, so we use one of
  # its built-in fake AMIs (override with -var="localstack_ami_id=ami-..." if
  # your LocalStack version uses a different ID). On real AWS (null) the
  # module looks up Ubuntu 24.04.
  ami_id = var.use_localstack ? var.localstack_ami_id : null
}

# Stops 'terraform apply' in the "default" workspace (or a typo'd one).
resource "terraform_data" "workspace_guard" {
  lifecycle {
    precondition {
      condition     = contains(keys(local.env_config), terraform.workspace)
      error_message = "Workspace '${terraform.workspace}' is not valid. Run: terraform workspace select -or-create dev   (or staging / prod)."
    }
  }
}
