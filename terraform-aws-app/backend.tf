# Where Terraform keeps its state file.
#
# LEARNING / LOCALSTACK: state lives on your disk. Each workspace gets its own
# file under terraform.tfstate.d/<workspace>/terraform.tfstate.
#
# REAL AWS: switch to the S3 backend. See backend.s3.example and the README
# ("Step 10 - Move to real AWS"). Never commit state files to git.
terraform {
  backend "local" {}
}
