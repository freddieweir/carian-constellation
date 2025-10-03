# Security Configuration - KMS, Security Groups

# ============================================================================
# KMS Keys for Encryption
# ============================================================================

# KMS key for EKS cluster secrets encryption
resource "aws_kms_key" "eks" {
  count = var.enable_cluster_encryption ? 1 : 0
  
  description             = "EKS cluster secrets encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  tags = merge(
    local.security_tags,
    {
      Name      = "${local.name_prefix}-eks-secrets"
      Service   = "kms"
      Component = "encryption"
      Purpose   = "eks-secrets-encryption"
      Critical  = "true"
    }
  )
}

resource "aws_kms_alias" "eks" {
  count = var.enable_cluster_encryption ? 1 : 0
  
  name          = "alias/${local.name_prefix}-eks"
  target_key_id = aws_kms_key.eks[0].key_id
}

# KMS key for EBS volume encryption
resource "aws_kms_key" "ebs" {
  count = var.enable_ebs_encryption ? 1 : 0
  
  description             = "EBS volume encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  tags = merge(
    local.security_tags,
    {
      Name      = "${local.name_prefix}-ebs"
      Service   = "kms"
      Component = "encryption"
      Purpose   = "ebs-encryption"
      Critical  = "true"
    }
  )
}

resource "aws_kms_alias" "ebs" {
  count = var.enable_ebs_encryption ? 1 : 0
  
  name          = "alias/${local.name_prefix}-ebs"
  target_key_id = aws_kms_key.ebs[0].key_id
}

# ============================================================================
# Additional Node Security Group Rules
# ============================================================================

# This will be attached to the EKS node security group
resource "aws_security_group_rule" "node_to_tailscale" {
  count = var.enable_tailscale ? 1 : 0
  
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.tailscale_relay[0].id
  security_group_id        = module.eks.node_security_group_id
  description              = "Allow nodes to communicate with Tailscale relay"
}

# ============================================================================
# ALB Security Group
# ============================================================================

resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Security group for internal ALB"
  vpc_id      = module.vpc.vpc_id
  
  tags = merge(
    local.security_tags,
    {
      Name      = "${local.name_prefix}-alb-sg"
      Service   = "load-balancing"
      Component = "alb-security-group"
    }
  )
  
  lifecycle {
    create_before_destroy = true
  }
}

# Allow HTTPS from Tailscale relay
resource "aws_security_group_rule" "alb_https_from_tailscale" {
  count = var.enable_tailscale ? 1 : 0
  
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tailscale_relay[0].id
  security_group_id        = aws_security_group.alb.id
  description              = "HTTPS from Tailscale relay only"
}

# Allow HTTP from Tailscale relay (for redirects)
resource "aws_security_group_rule" "alb_http_from_tailscale" {
  count = var.enable_tailscale ? 1 : 0
  
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.tailscale_relay[0].id
  security_group_id        = aws_security_group.alb.id
  description              = "HTTP from Tailscale relay only"
}

# Allow outbound to EKS nodes
resource "aws_security_group_rule" "alb_to_nodes" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = module.eks.node_security_group_id
  security_group_id        = aws_security_group.alb.id
  description              = "Allow ALB to reach EKS nodes"
}

# ============================================================================
# CloudWatch Log Groups
# ============================================================================

resource "aws_cloudwatch_log_group" "eks_cluster" {
  count = var.enable_cluster_logging ? 1 : 0
  
  name              = "/aws/eks/${local.name_prefix}/cluster"
  retention_in_days = var.log_retention_days
  
  tags = merge(
    local.monitoring_tags,
    {
      Name      = "${local.name_prefix}-eks-logs"
      Service   = "observability"
      Component = "cloudwatch-logs"
      LogType   = "eks-control-plane"
    }
  )
}
