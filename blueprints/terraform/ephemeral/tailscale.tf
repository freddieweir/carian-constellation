# ============================================================================
# Tailscale Relay - Secure Access to Private EKS Cluster
# ============================================================================

# Latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ============================================================================
# Security Group for Tailscale Relay
# ============================================================================

resource "aws_security_group" "tailscale_relay" {
  name        = "${local.cluster_name}-tailscale-relay"
  description = "Security group for Tailscale relay instance"
  vpc_id      = module.vpc.vpc_id

  # Tailscale UDP port (for DERP relay)
  ingress {
    description = "Tailscale DERP"
    from_port   = 41641
    to_port     = 41641
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Tailscale listening port
  ingress {
    description = "Tailscale"
    from_port   = 41641
    to_port     = 41641
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access (optional, for debugging)
  ingress {
    description = "SSH from authorized IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_public_access_cidrs
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-tailscale-relay"
    }
  )
}

# ============================================================================
# IAM Role for Tailscale Relay Instance
# ============================================================================

resource "aws_iam_role" "tailscale_relay" {
  name = "${local.cluster_name}-tailscale-relay-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-tailscale-relay-role"
    }
  )
}

# Attach SSM policy for Session Manager access
resource "aws_iam_role_policy_attachment" "tailscale_relay_ssm" {
  role       = aws_iam_role.tailscale_relay.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch metrics and logs
resource "aws_iam_role_policy_attachment" "tailscale_relay_cloudwatch" {
  role       = aws_iam_role.tailscale_relay.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Custom policy for EKS cluster access
resource "aws_iam_role_policy" "tailscale_relay_eks" {
  name = "${local.cluster_name}-tailscale-eks-access"
  role = aws_iam_role.tailscale_relay.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = module.eks.cluster_arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "tailscale_relay" {
  name = "${local.cluster_name}-tailscale-relay-profile"
  role = aws_iam_role.tailscale_relay.name

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-tailscale-relay-profile"
    }
  )
}

# ============================================================================
# User Data Script Template
# ============================================================================

data "template_file" "tailscale_userdata" {
  template = file("${path.module}/templates/tailscale-relay-userdata.sh")

  vars = {
    TAILSCALE_AUTH_KEY    = var.tailscale_auth_key
    AWS_REGION            = var.aws_region
    CLUSTER_NAME          = local.cluster_name
    VPC_CIDR              = module.vpc.vpc_cidr_block
    ENVIRONMENT           = var.environment
    PROJECT_NAME          = var.project_name
  }
}

# ============================================================================
# Tailscale Relay EC2 Instance
# ============================================================================

resource "aws_instance" "tailscale_relay" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.tailscale_instance_type

  # Network configuration - deploy in public subnet for internet access
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.tailscale_relay.id]
  associate_public_ip_address = true

  # IAM configuration
  iam_instance_profile = aws_iam_instance_profile.tailscale_relay.name

  # User data script
  user_data = data.template_file.tailscale_userdata.rendered

  # Enable detailed monitoring
  monitoring = true

  # Enable termination protection for production
  disable_api_termination = var.environment == "production" ? true : false

  # Root volume configuration
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
    
    tags = merge(
      local.common_tags,
      {
        Name = "${local.cluster_name}-tailscale-relay-root"
      }
    )
  }

  # Metadata service v2 (IMDSv2) required for better security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-tailscale-relay"
      Role = "TailscaleRelay"
    }
  )

  # Ensure VPC and EKS cluster exist first
  depends_on = [
    module.vpc,
    module.eks
  ]

  lifecycle {
    ignore_changes = [
      ami,           # Don't recreate if AMI updates
      user_data      # Don't recreate if user data changes (manual update)
    ]
  }
}

# ============================================================================
# CloudWatch Alarms for Tailscale Relay
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "tailscale_relay_status_check" {
  alarm_name          = "${local.cluster_name}-tailscale-relay-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alert when Tailscale relay instance fails status checks"
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = aws_instance.tailscale_relay.id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "tailscale_relay_cpu" {
  alarm_name          = "${local.cluster_name}-tailscale-relay-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when Tailscale relay CPU exceeds 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.tailscale_relay.id
  }

  tags = local.common_tags
}

# ============================================================================
# Elastic IP for Stable Tailscale Relay Address (Optional)
# ============================================================================

resource "aws_eip" "tailscale_relay" {
  count    = var.use_tailscale_eip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.tailscale_relay.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-tailscale-relay-eip"
    }
  )

  depends_on = [aws_instance.tailscale_relay]
}
