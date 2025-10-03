# VPC and Networking Configuration

# ============================================================================
# VPC Module
# ============================================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnet_cidrs
  public_subnets  = local.public_subnet_cidrs

  # NAT Gateway configuration
  enable_nat_gateway   = true
  single_nat_gateway   = var.single_nat_gateway  # Cost optimization: single NAT
  one_nat_gateway_per_az = var.enable_nat_gateway_ha
  
  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs (optional, costs extra)
  enable_flow_log                      = false
  create_flow_log_cloudwatch_iam_role  = false
  create_flow_log_cloudwatch_log_group = false

  # Kubernetes-specific subnet tags
  public_subnet_tags = merge(
    local.network_tags,
    local.public_subnet_tags,
    {
      Name = "${local.name_prefix}-public"
      Tier = "public"
    }
  )

  private_subnet_tags = merge(
    local.network_tags,
    local.private_subnet_tags,
    {
      Name = "${local.name_prefix}-private"
      Tier = "private"
    }
  )

  # VPC tags
  tags = merge(
    local.network_tags,
    {
      Name = "${local.name_prefix}-vpc"
    }
  )

  # NAT Gateway tags
  nat_gateway_tags = merge(
    local.network_tags,
    {
      Name      = "${local.name_prefix}-nat"
      Component = "nat-gateway"
    }
  )

  # Internet Gateway tags
  igw_tags = merge(
    local.network_tags,
    {
      Name      = "${local.name_prefix}-igw"
      Component = "internet-gateway"
    }
  )
}

# ============================================================================
# VPC Endpoints (for private EKS access)
# ============================================================================

# S3 VPC Endpoint (Gateway endpoint - free!)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.${local.region}.s3"
  
  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.public_route_table_ids
  )
  
  tags = merge(
    local.network_tags,
    {
      Name      = "${local.name_prefix}-s3-endpoint"
      Service   = "networking"
      Component = "vpc-endpoint"
      Endpoint  = "s3"
    }
  )
}

# ECR API VPC Endpoint (for pulling container images privately)
resource "aws_vpc_endpoint" "ecr_api" {
  count = var.enable_private_endpoint ? 1 : 0
  
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${local.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true
  
  tags = merge(
    local.network_tags,
    {
      Name      = "${local.name_prefix}-ecr-api-endpoint"
      Component = "vpc-endpoint"
      Endpoint  = "ecr-api"
    }
  )
}

# ECR DKR VPC Endpoint (for pulling container images privately)
resource "aws_vpc_endpoint" "ecr_dkr" {
  count = var.enable_private_endpoint ? 1 : 0
  
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${local.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true
  
  tags = merge(
    local.network_tags,
    {
      Name      = "${local.name_prefix}-ecr-dkr-endpoint"
      Component = "vpc-endpoint"
      Endpoint  = "ecr-dkr"
    }
  )
}

# CloudWatch Logs VPC Endpoint (for private logging)
resource "aws_vpc_endpoint" "logs" {
  count = var.enable_private_endpoint ? 1 : 0
  
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${local.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true
  
  tags = merge(
    local.network_tags,
    {
      Name      = "${local.name_prefix}-logs-endpoint"
      Component = "vpc-endpoint"
      Endpoint  = "cloudwatch-logs"
    }
  )
}

# ============================================================================
# Security Group for VPC Endpoints
# ============================================================================

resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name_prefix = "${local.name_prefix}-vpc-endpoints-"
  description = "Security group for VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.security_tags,
    {
      Name      = "${local.name_prefix}-vpc-endpoints-sg"
      Component = "vpc-endpoint-sg"
    }
  )
  
  lifecycle {
    create_before_destroy = true
  }
}
