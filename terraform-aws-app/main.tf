# Root module: wires the five building blocks together.
# Read top to bottom - each module's outputs feed the next module's inputs.

module "network" {
  source = "./modules/network"

  name_prefix                = local.name_prefix
  aws_region                 = var.aws_region
  vpc_cidr                   = local.config.vpc_cidr
  az_count                   = local.config.az_count
  single_nat_gateway         = local.config.single_nat_gateway
  enable_s3_gateway_endpoint = !var.use_localstack

  depends_on = [terraform_data.workspace_guard]
}

module "storage" {
  source = "./modules/storage"

  name_prefix       = local.name_prefix
  force_destroy     = local.config.bucket_force_destroy
  enable_versioning = local.config.bucket_versioning

  depends_on = [terraform_data.workspace_guard]
}

module "messaging" {
  source = "./modules/messaging"

  name_prefix        = local.name_prefix
  bucket_id          = module.storage.bucket_id
  bucket_arn         = module.storage.bucket_arn
  upload_prefix      = "uploads/"
  lambda_memory_mb   = local.config.lambda_memory_mb
  lambda_timeout_s   = local.config.lambda_timeout_s
  max_receive_count  = local.config.sqs_max_receive_count
  log_retention_days = local.config.log_retention_days
}

module "compute" {
  source = "./modules/compute"

  name_prefix             = local.name_prefix
  aws_region              = var.aws_region
  vpc_id                  = module.network.vpc_id
  public_subnet_ids       = module.network.public_subnet_ids
  private_subnet_ids      = module.network.private_subnet_ids
  ami_id                  = local.ami_id
  frontend_instance_type  = local.config.frontend_instance
  backend_instance_type   = local.config.backend_instance
  root_volume_gb          = local.config.root_volume_gb
  termination_protection  = local.config.termination_protect
  allowed_http_cidrs      = var.allowed_http_cidrs
  bucket_arn              = module.storage.bucket_arn
  bucket_name             = module.storage.bucket_id
  queue_arn               = module.messaging.queue_arn
  queue_url               = module.messaging.queue_url
  backend_container_image = var.backend_container_image

  # NAT must exist before instances boot, otherwise user_data cannot reach
  # the internet to install packages.
  depends_on = [module.network]
}

module "cdn" {
  source = "./modules/cdn"

  enable                      = var.enable_cloudfront
  name_prefix                 = local.name_prefix
  bucket_regional_domain_name = module.storage.bucket_regional_domain_name
  price_class                 = local.config.cloudfront_price
}
