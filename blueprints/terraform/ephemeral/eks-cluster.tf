# ============================================================================
# EKS Cluster - Ephemeral Kubernetes Infrastructure
# ============================================================================

# Data source for EKS cluster auth
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# ============================================================================
# EKS Module
# ============================================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  # Cluster endpoint access
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  
  # Allow access from specific IPs (including Tailscale relay)
  cluster_endpoint_public_access_cidrs = concat(
    var.allowed_public_access_cidrs,
    ["${aws_instance.tailscale_relay.public_ip}/32"] # Tailscale relay IP
  )

  # VPC Configuration
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Cluster encryption
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # CloudWatch logging
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  # Cluster addons with latest versions
  cluster_addons = {
    coredns = {
      most_recent = true
      preserve    = false
    }
    kube-proxy = {
      most_recent = true
      preserve    = false
    }
    vpc-cni = {
      most_recent              = true
      preserve                 = false
      service_account_role_arn = aws_iam_role.vpc_cni_role.arn
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          ENABLE_POD_ENI           = "true"
          POD_SECURITY_GROUP_ENFORCING_MODE = "standard"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      preserve                 = false
      service_account_role_arn = aws_iam_role.ebs_csi_role.arn
    }
  }

  # OIDC Provider for IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
    
    # Allow Tailscale relay to communicate with cluster
    ingress_tailscale_relay = {
      description = "Tailscale relay access"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      source_security_group_id = aws_security_group.tailscale_relay.id
    }
  }

  # Node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    
    ingress_cluster_all = {
      description                   = "Cluster to node all ports/protocols"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
    
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    
    # Allow Tailscale relay to communicate with nodes
    ingress_tailscale_relay = {
      description              = "Tailscale relay access"
      protocol                 = "-1"
      from_port                = 0
      to_port                  = 0
      type                     = "ingress"
      source_security_group_id = aws_security_group.tailscale_relay.id
    }
  }

  # ============================================================================
  # EKS Managed Node Groups
  # ============================================================================

  eks_managed_node_groups = {
    # Primary node group for general workloads
    general = {
      name            = "${local.cluster_name}-general"
      use_name_prefix = false
      
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type # "SPOT" or "ON_DEMAND"
      
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
      
      # Use latest Amazon Linux 2 EKS optimized AMI
      ami_type = "AL2_x86_64"
      
      # Disk configuration
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = var.node_disk_size
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            kms_key_id            = aws_kms_key.ebs.arn
            delete_on_termination = true
          }
        }
      }
      
      # IAM role for nodes
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        CloudWatchAgentServerPolicy  = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }
      
      # Node labels for workload scheduling
      labels = {
        Environment = var.environment
        Workload    = "general"
      }
      
      # Node taints (none for general workload)
      taints = []
      
      # Tags
      tags = merge(
        local.common_tags,
        {
          Name = "${local.cluster_name}-general-node"
        }
      )
    }
  }

  # Access entries for cluster authentication
  access_entries = {
    # Admin access for the creator
    admin = {
      principal_arn = data.aws_caller_identity.current.arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Tags applied to all EKS resources
  tags = local.common_tags
}

# ============================================================================
# IAM Roles for Service Accounts (IRSA)
# ============================================================================

# VPC CNI Role
resource "aws_iam_role" "vpc_cni_role" {
  name               = "${local.cluster_name}-vpc-cni-role"
  assume_role_policy = data.aws_iam_policy_document.vpc_cni_assume_role.json
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-vpc-cni-role"
    }
  )
}

data "aws_iam_policy_document" "vpc_cni_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }
    
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
    
    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
  role       = aws_iam_role.vpc_cni_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# EBS CSI Driver Role
resource "aws_iam_role" "ebs_csi_role" {
  name               = "${local.cluster_name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-ebs-csi-role"
    }
  )
}

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
    
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
    
    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.ebs_csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}
