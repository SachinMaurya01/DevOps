# Terraform Guide — Basics to Advanced (AWS Focused)

> Focused edition: **VPC, Subnet, Internet Gateway, EC2, S3, EKS only** + core Terraform concepts.
> Terraform `>= 1.5` | AWS Provider `~> 5.0`

## Table of Contents

1. [What is Terraform & IaC](#1-what-is-terraform--iac)
2. [Core Concepts & HCL Syntax](#2-core-concepts--hcl-syntax)
3. [Terraform Workflow](#3-terraform-workflow)
4. [Providers – AWS Configuration](#4-providers--aws-configuration)
5. [Resources – Basics](#5-resources--basics)
6. [Data Sources](#6-data-sources)
7. [Variables, tfvars, Validation](#7-variables-tfvars-validation)
8. [Outputs](#8-outputs)
9. [Locals](#9-locals)
10. [Terraform State & Backend (S3)](#10-terraform-state--backend-s3)
11. [Meta-Arguments](#11-meta-arguments)
12. [Conditionals, Functions, Dynamic Blocks](#12-conditionals-functions-dynamic-blocks)
13. [Modules](#13-modules)
14. [Workspaces / Environments](#14-workspaces--environments)
15. [Import Existing Resources](#15-import-existing-resources)
16. [Networking: VPC, Subnet, Internet Gateway](#16-networking-vpc-subnet-internet-gateway)
17. [Compute: EC2](#17-compute-ec2)
18. [Storage: S3](#18-storage-s3)
19. [Containers: EKS](#19-containers-eks)
20. [Testing, Formatting, Validation](#20-testing-formatting-validation)
21. [Security Best Practices](#21-security-best-practices)
22. [Project Structure](#22-project-structure)
23. [Troubleshooting](#23-troubleshooting)
24. [Cheat Sheet](#24-cheat-sheet)
25. [Mini-Project](#25-mini-project)

---

## 1. What is Terraform & IaC

- **Infrastructure as Code (IaC):** manage infra via code, not clicks.
- **Terraform:** declarative, cloud-agnostic. You define desired state, Terraform creates it.
- **How it works:** write `.tf` → `init` → `plan` → `apply` → state saved in `terraform.tfstate`.

```hcl
# Declarative example: you say WHAT, not HOW
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}
```

---

## 2. Core Concepts & HCL Syntax

| Concept | Meaning |
|---|---|
| `provider` | Plugin to talk to AWS |
| `resource` | Something to create (`aws_instance`, `aws_s3_bucket`) |
| `data` | Read-only lookup (`data "aws_ami"`) |
| `variable` | Input parameter |
| `output` | Return value after apply |
| `state` | JSON mapping code → real AWS IDs |
| `module` | Reusable folder of `.tf` files |
| `backend` | Where state is stored (`s3`) |

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  tags = {
    Name = "HelloWorld"
  }
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

output "instance_id" {
  value = aws_instance.web.id
}
```

HCL types: `string`, `number`, `bool`, `list(string)`, `map(string)`, `object`, `set`.

---

## 3. Terraform Workflow

```bash
terraform init        # download providers, setup backend
terraform validate    # syntax check
terraform fmt         # format code
terraform plan        # dry-run diff (save: -out=tfplan)
terraform apply       # create infra (use file: apply "tfplan")
terraform destroy     # delete all
terraform output      # show outputs
terraform state list  # list resources in state
```

```bash
mkdir demo && cd demo
# create main.tf
terraform init
terraform plan
terraform apply      # type yes
terraform destroy
```

---

## 4. Providers – AWS Configuration

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "dev" # optional, uses ~/.aws/credentials

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Environment = var.environment
      Project     = "myapp"
    }
  }
}
```

Multi-region with alias:

```hcl
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

resource "aws_s3_bucket" "west" {
  provider = aws.west
  bucket   = "my-west-bucket-unique-123"
}
```

Cross-account (prod best practice):

```hcl
provider "aws" {
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::123456789012:role/TerraformDeployer"
  }
}
```

Version constraints: `~> 5.0` = `>=5.0, <6.0`, `= 5.31.0` = exact.

---

## 5. Resources – Basics

Syntax:

```hcl
resource "<PROVIDER>_<TYPE>" "<LOCAL_NAME>" {
  argument = value
}
```

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  tags = { Name = "web-server" }
}
# Access: aws_instance.web.id, aws_instance.web.public_ip
```

---

## 6. Data Sources

Fetch existing info, don't create.

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "azs" {
  value = data.aws_availability_zones.available.names
}
```

Read remote state from another stack:

```hcl
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "my-tf-state-bucket"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}
# Usage: data.terraform_remote_state.network.outputs.vpc_id
```

---

## 7. Variables, tfvars, Validation

`variables.tf`:

```hcl
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "tags" {
  type = map(string)
  default = {
    Project = "demo"
    Owner   = "devops"
  }
}

variable "db_password" {
  type      = string
  sensitive = true
}
```

`terraform.tfvars` (auto-loaded):

```hcl
aws_region    = "us-east-1"
environment   = "dev"
instance_type = "t3.small"
```

Usage:

```bash
terraform plan -var-file="prod.tfvars"
terraform plan -var="instance_type=t3.micro"
export TF_VAR_instance_type="t3.micro"
```

Precedence (low → high): `default` → `terraform.tfvars` → `*.auto.tfvars` → `-var-file` → `-var` / `TF_VAR_`.

---

## 8. Outputs

`outputs.tf`:

```hcl
output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "bucket_name" {
  value = aws_s3_bucket.app.id
}
```

```bash
terraform output
terraform output instance_id
terraform output -raw instance_id
```

---

## 9. Locals

Internal computed values, not user inputs. Use for naming + common tags.

```hcl
locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
  bucket_name = lower("${local.name_prefix}-assets-${data.aws_caller_identity.current.account_id}")
}

resource "aws_s3_bucket" "assets" {
  bucket = local.bucket_name
  tags   = local.common_tags
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web"
  })
}
```

---

## 10. Terraform State & Backend (S3)

- `terraform.tfstate`: maps code → real IDs. Never edit manually.
- `.terraform/`: provider cache. Safe to delete.
- `.terraform.lock.hcl`: commit to git.

```bash
terraform state list
terraform state show aws_instance.web
terraform state mv aws_s3_bucket.old aws_s3_bucket.new
terraform state rm aws_instance.web  # remove from state only, not destroy
terraform apply -replace="aws_instance.web"  # force recreate
```

`.gitignore`:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
crash.log
```

Backend setup — create bucket once (bootstrap), then use it:

```hcl
# bootstrap: state bucket
resource "aws_s3_bucket" "tfstate" {
  bucket = "my-org-tfstate-123456789012-unique"
}

resource "aws_s3_bucket_versioning" "v" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "e" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "p" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

```hcl
# backend.tf in every project
terraform {
  backend "s3" {
    bucket       = "my-org-tfstate-123456789012-unique"
    key          = "dev/network/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # S3 native locking (modern, no DynamoDB needed)
  }
}
```

```bash
terraform init -migrate-state
terraform init -reconfigure
```

---

## 11. Meta-Arguments

### count

```hcl
resource "aws_instance" "worker" {
  count         = 3
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  tags = { Name = "worker-${count.index}" }
}
# aws_instance.worker[0].id, aws_instance.worker[*].id
```

### for_each (preferred over count)

```hcl
variable "buckets" {
  type    = set(string)
  default = ["logs", "assets"]
}

resource "aws_s3_bucket" "b" {
  for_each = var.buckets
  bucket   = "myapp-${each.key}-98765-unique"
}
# aws_s3_bucket.b["logs"].id
```

### depends_on

```hcl
resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  depends_on    = [aws_internet_gateway.main]
}
# Most deps are implicit via references. Use only when no direct reference.
```

### lifecycle

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true   # protect prod
    ignore_changes        = [tags, ami]
  }
}
```

### moved (refactoring without destroy)

```hcl
moved {
  from = aws_instance.old_name
  to   = aws_instance.new_name
}
```

---

## 12. Conditionals, Functions, Dynamic Blocks

Conditional:

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"
}
```

Common functions:

```hcl
locals {
  a = upper(var.environment)             # "DEV"
  b = format("app-%s-%s", var.project, var.environment)
  c = join(",", ["a", "b"])
  d = length(var.allowed_ports)
  e = file("${path.module}/user-data.sh")
  f = jsonencode({ Name = "web" })
  g = cidrsubnet("10.0.0.0/16", 8, 1)   # "10.0.1.0/24"
}

output "ids" { value = aws_instance.worker[*].id }

# for expression
output "upper_azs" {
  value = [for az in data.aws_availability_zones.available.names : upper(az)]
}
```

Dynamic blocks (for repeated nested blocks like `ingress`):

```hcl
variable "ingress_rules" {
  type = list(object({
    port        = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    { port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "HTTP" },
    { port = 22, protocol = "tcp", cidr_blocks = ["10.0.0.0/8"], description = "SSH" }
  ]
}

resource "aws_security_group" "web" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

---

## 13. Modules

Use registry module (VPC):

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = { Environment = "dev" }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = module.vpc.public_subnets[0]
}
```

Create your own — `modules/ec2/main.tf`:

```hcl
resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  tags = merge(var.tags, { Name = var.name })
}
```

`modules/ec2/variables.tf`:

```hcl
variable "name" { type = string }
variable "ami_id" { type = string }
variable "instance_type" { type = string default = "t3.micro" }
variable "subnet_id" { type = string }
variable "security_group_ids" { type = list(string) default = [] }
variable "tags" { type = map(string) default = {} }
```

`modules/ec2/outputs.tf`:

```hcl
output "instance_id" { value = aws_instance.this.id }
output "public_ip" { value = aws_instance.this.public_ip }
```

Use it:

```hcl
module "web" {
  source      = "./modules/ec2"
  name        = "web-server"
  ami_id      = data.aws_ami.amazon_linux.id
  subnet_id   = module.vpc.public_subnets[0]
  tags        = { Environment = "dev" }
}
```

---

## 14. Workspaces / Environments

Simple (workspaces):

```bash
terraform workspace new dev
terraform workspace new prod
terraform workspace select dev
```

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = terraform.workspace == "prod" ? "t3.large" : "t3.micro"
  tags = { Name = "web-${terraform.workspace}" }
}
```

Recommended for prod: folder per env + separate backend keys:

```text
live/
  dev/backend.tf   # key = "dev/terraform.tfstate"
  prod/backend.tf  # key = "prod/terraform.tfstate"
```

---

## 15. Import Existing Resources

```hcl
resource "aws_s3_bucket" "imported" {
  bucket = "my-manually-created-bucket-xyz"
}

import {
  to = aws_s3_bucket.imported
  id = "my-manually-created-bucket-xyz"
}
```

```bash
terraform plan -generate-config-out=generated.tf
terraform plan  # ensure no diff, then apply
```

EC2 example:

```hcl
import {
  to = aws_instance.web
  id = "i-0abcd1234efgh5678"
}
```

Old CLI way: `terraform import aws_s3_bucket.imported my-bucket-name`

---

## 16. Networking: VPC, Subnet, Internet Gateway

Full public VPC (no NAT — public subnets only):

```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "main" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main-igw" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = { Name = "public-b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}
```

Security group for EC2 in this VPC:

```hcl
resource "aws_security_group" "web" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH - restrict to your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "web-sg" }
}
```

Shortcut with registry module (public subnets only):

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"
  name    = "main"
  cidr    = "10.0.0.0/16"
  azs     = ["us-east-1a", "us-east-1b"]
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_dns_hostnames = true
}
```

---

## 17. Compute: EC2

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_key_pair" "main" {
  key_name   = "my-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.main.key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl enable --now httpd
    echo "<h1>Hello from Terraform EC2</h1>" > /var/www/html/index.html
  EOF

  tags = { Name = "web" }
}

output "public_ip" { value = aws_instance.web.public_ip }
```

Launch template (for EKS node groups / ASG-style):

```hcl
resource "aws_launch_template" "web" {
  name_prefix   = "web-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web.id]
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl enable --now httpd
  EOF
  )
}
```

IAM role for EC2 (S3 read + SSM, no SSH keys needed):

```hcl
resource "aws_iam_role" "ec2_role" {
  name = "ec2-s3-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# In aws_instance: iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
# Connect via: aws ssm start-session --target i-xxxx
```

---

## 18. Storage: S3

Private bucket with best-practice defaults:

```hcl
resource "aws_s3_bucket" "app" {
  bucket = "my-app-bucket-987654321-unique" # globally unique
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket                  = aws_s3_bucket.app.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

Static website hosting:

```hcl
resource "aws_s3_bucket" "site" {
  bucket = "my-static-site-123456-unique"
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  index_document { suffix = "index.html" }
  error_document { key = "error.html" }
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  content      = "<h1>Hello from S3 + Terraform</h1>"
  content_type = "text/html"
}

output "website_url" {
  value = aws_s3_bucket_website_configuration.site.website_endpoint
}
```

Random suffix to avoid `BucketAlreadyExists`:

```hcl
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "app" {
  bucket = "myapp-${var.environment}-${random_string.suffix.result}"
}
```

---

## 19. Containers: EKS

> Don't hand-roll EKS — use `terraform-aws-modules/eks/aws`.

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"
  name    = "eks-vpc"
  cidr    = "10.0.0.0/16"
  azs     = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "my-eks"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    default = {
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      instance_types = ["t3.medium"]
    }
  }

  tags = { Environment = "dev" }
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}
```

Connect after apply:

```bash
aws eks update-kubeconfig --region us-east-1 --name my-eks
kubectl get nodes
```

ECR repo for EKS images:

```hcl
resource "aws_ecr_repository" "app" {
  name                 = "myapp"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

output "ecr_url" { value = aws_ecr_repository.app.repository_url }
```

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ecr_url>
docker build -t myapp .
docker tag myapp:latest <ecr_url>:latest
docker push <ecr_url>:latest
```

IAM Roles for Service Accounts (IRSA) — let pods access S3 without keys:

```hcl
module "irsa_s3" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "pod-s3-read"
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:myapp-sa"]
    }
  }

  role_policy_arns = {
    s3 = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  }
}
```

---

## 20. Testing, Formatting, Validation

```bash
terraform fmt -check -recursive
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
```

Native test (`*.tftest.hcl`, TF 1.6+):

```hcl
# tests/basic.tftest.hcl
run "valid_instance_type" {
  command = plan
  assert {
    condition     = aws_instance.web.instance_type == "t3.micro"
    error_message = "Wrong instance type"
  }
}
```

```bash
terraform test
```

Security scanners: `tflint`, `tfsec`, `checkov -d . --framework terraform`.

---

## 21. Security Best Practices

1. No hardcoded secrets — use `sensitive` vars, env vars, SSM/Secrets Manager.
2. S3 state bucket: versioning + SSE + public-access-block + `use_lockfile`.
3. Encrypt EBS (`encrypted = true`), S3 (SSE), EKS secrets encryption.
4. Least-open SGs — never `0.0.0.0/0` for SSH. Use SSM Session Manager.
5. `prevent_destroy = true` for prod S3 / EKS.
6. Pin providers + commit `.terraform.lock.hcl`.
7. Separate state per env (`dev/` vs `prod/` keys).
8. Scan in CI: `checkov`, `tflint`.

```hcl
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "prod/db/password"
}
# password = data.aws_secretsmanager_secret_version.db.secret_string
# Note: secret value still lands in state — restrict state access.
```

---

## 22. Project Structure

Small:

```text
main.tf
variables.tf
outputs.tf
backend.tf
terraform.tfvars
```

Production (recommended):

```text
live/
  network/   # VPC only (key=network/terraform.tfstate)
    main.tf  variables.tf  outputs.tf  backend.tf
  compute/   # EC2 (key=compute/terraform.tfstate)
  storage/   # S3
  eks/       # EKS
modules/
  vpc/
  ec2/
envs/
  dev.tfvars
  prod.tfvars
```

`versions.tf`:

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
```

Rules: one state per blast radius, DRY via modules, no console drift, `plan` on PR / `apply` on main.

---

## 23. Troubleshooting

| Error | Fix |
|---|---|
| `BucketAlreadyExists` | S3 names global — add `random_string` suffix |
| Provider lock error | `rm -rf .terraform && terraform init -upgrade` |
| State lock stuck | Wait or `terraform force-unlock <ID>` |
| `InvalidAMIID` | AMI wrong region — use `data "aws_ami"` |
| `Cycle` error | Remove circular `depends_on` |
| Wrong env changed | Check workspace / `-var-file` / backend `key` |
| Auth error | `aws sts get-caller-identity`, check `AWS_PROFILE` |
| Debug | `TF_LOG=DEBUG terraform plan` |

---

## 24. Cheat Sheet

```bash
terraform init && terraform fmt -recursive && terraform validate && terraform plan -out=tfplan && terraform apply tfplan

terraform output
terraform state list
terraform workspace new dev
terraform import aws_s3_bucket.b my-bucket
terraform apply -replace="aws_instance.web"
terraform apply -target=aws_instance.web   # sparingly
TF_LOG=DEBUG terraform plan
```

Interview quick answers:

- **State?** JSON mapping config → real IDs. Remote S3 for sharing/locking/versioning.
- **count vs for_each?** `count` = index, shifts on delete. `for_each` = stable keys. Prefer `for_each`.
- **Multi-env?** Separate states + tfvars, modules for DRY.
- **Secrets?** Sensitive vars, Secrets Manager, encrypted state, gitignore tfvars.

---

## 25. Mini-Project

VPC (public) + EC2 + S3 + EKS wiring — combine sections 16–19:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"
  name    = "demo"
  cidr    = "10.0.0.0/16"
  azs     = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
}

resource "aws_s3_bucket" "assets" {
  bucket = "demo-assets-unique-123456"
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = module.vpc.public_subnets[0]
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.0"
  cluster_name    = "demo-eks"
  cluster_version = "1.29"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  eks_managed_node_groups = {
    default = {
      min_size       = 1
      max_size       = 2
      desired_size   = 1
      instance_types = ["t3.medium"]
    }
  }
}
```

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
aws eks update-kubeconfig --region us-east-1 --name demo-eks
kubectl get nodes
terraform destroy
```

