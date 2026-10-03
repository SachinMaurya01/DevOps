# Two Ubuntu EC2 instances:
#
#   frontend  (PUBLIC subnet, Elastic IP)   nginx serves the web app and
#                                            proxies /api/ to the backend
#   backend   (PRIVATE subnet, no public IP) nginx -> Docker container
#
# Only the frontend is reachable from the internet. The backend accepts
# traffic from the frontend's security group and nothing else.
# There is no SSH: use AWS Systems Manager Session Manager (see README).

# ---- AMI -------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = coalesce(var.ami_id, one(data.aws_ami.ubuntu[*].id))
}

# ---- Security groups -------------------------------------------------------

resource "aws_security_group" "frontend" {
  name        = "${var.name_prefix}-frontend-sg"
  description = "Public web traffic to the frontend"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-frontend-sg" }
}

resource "aws_security_group" "backend" {
  name        = "${var.name_prefix}-backend-sg"
  description = "Backend accepts traffic only from the frontend"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from frontend"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    description = "All outbound (via NAT)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-backend-sg" }
}

# ---- IAM: what the instances may do in AWS --------------------------------

resource "aws_iam_role" "instance" {
  name = "${var.name_prefix}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Lets you open a shell through Session Manager instead of SSH keys.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "app_access" {
  name = "${var.name_prefix}-app-access"
  role = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "FilesBucketObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${var.bucket_arn}/*"
      },
      {
        Sid      = "FilesBucketList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = var.bucket_arn
      },
      {
        Sid      = "SendJobs"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
        Resource = var.queue_arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name_prefix}-instance-profile"
  role = aws_iam_role.instance.name
}

# ---- Backend (private) -----------------------------------------------------

resource "aws_instance" "backend" {
  ami                    = local.ami_id
  instance_type          = var.backend_instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.backend.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  disable_api_termination = var.termination_protection

  # IMDSv2 only: blocks the classic SSRF-to-credentials attack.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2 # 2 so Docker containers can reach it
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_gb
    encrypted   = true
  }

  user_data = templatefile("${path.module}/templates/backend.sh.tpl", {
    base_install  = file("${path.module}/templates/base_install.sh")
    backend_image = var.backend_container_image
    bucket_name   = var.bucket_name
    queue_url     = var.queue_url
    aws_region    = var.aws_region
  })
  user_data_replace_on_change = true

  tags = { Name = "${var.name_prefix}-backend", Role = "backend" }
}

# ---- Frontend (public) -----------------------------------------------------

resource "aws_instance" "frontend" {
  ami                    = local.ami_id
  instance_type          = var.frontend_instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.frontend.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  disable_api_termination = var.termination_protection

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_gb
    encrypted   = true
  }

  user_data = templatefile("${path.module}/templates/frontend.sh.tpl", {
    base_install       = file("${path.module}/templates/base_install.sh")
    backend_private_ip = aws_instance.backend.private_ip
  })
  user_data_replace_on_change = true

  tags = { Name = "${var.name_prefix}-frontend", Role = "frontend" }
}

# A fixed public IP that survives instance replacement.
resource "aws_eip" "frontend" {
  domain   = "vpc"
  instance = aws_instance.frontend.id

  tags = { Name = "${var.name_prefix}-frontend-eip" }
}
