# Local Values and Tagging Standards

locals {
  # Account and region info
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  # Naming
  name_prefix = var.cluster_name
  
  # Availability zones (auto-select first 2 if not specified)
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
  
  # ============================================================================
  # Comprehensive Tagging Strategy
  # ============================================================================
  
  # Base tags applied to ALL resources
  common_tags = {
    # Ownership & Contact
    Owner      = var.owner_name
    OwnerEmail = var.owner_email
    
    # Project & Organization
    Project    = "CarianConstellation"
    Repository = "github.com/${var.github_username}/carian-constellation"
    
    # Environment & Lifecycle
    Environment = "personal"
    Lifecycle   = "ephemeral"
    
    # Cost Management
    CostCenter     = "personal-projects"
    CostAllocation = "learning-development"
    BillingTeam    = var.owner_name
    
    # Technical Metadata
    ManagedBy       = "Terraform"
    TerraformRepo   = "github.com/${var.github_username}/carian-constellation"
    TerraformPath   = "terraform/ephemeral"
    TerraformModule = "ephemeral-infrastructure"
    
    # Operational
    BackupPolicy    = "daily-to-s3"
    MonitoringLevel = "standard"
    
    # Compliance & Security
    DataClassification = "personal"
    SecurityZone       = "restricted"
    Compliance         = "none"
    
    # Automation
    AutoShutdown    = "manual"
    AutoStart       = "manual"
    CanBeDestroyed  = "true"
    EphemeralCluster = "true"
  }
  
  # EKS-specific tags
  eks_tags = merge(local.common_tags, {
    Service       = "kubernetes"
    Component     = "eks-cluster"
    ClusterName   = var.cluster_name
    K8sVersion    = var.cluster_version
    Platform      = "aws-eks"
    Orchestration = "kubernetes"
  })
  
  # Networking tags
  network_tags = merge(local.common_tags, {
    Service   = "networking"
    Component = "vpc"
    Network   = "private"
  })
  
  # Security tags
  security_tags = merge(local.common_tags, {
    Service   = "security"
    Component = "security-group"
    Critical  = "true"
  })
  
  # Storage tags
  storage_tags = merge(local.common_tags, {
    Service   = "storage"
    Component = "ebs"
    Encrypted = "true"
  })
  
  # Monitoring tags
  monitoring_tags = merge(local.common_tags, {
    Service   = "observability"
    Component = "logging"
  })
  
  # Tailscale tags
  tailscale_tags = merge(local.common_tags, {
    Service   = "networking"
    Component = "vpn-gateway"
    Purpose   = "zero-trust-access"
    VPN       = "tailscale"
  })
  
  # ============================================================================
  # Kubernetes-specific tags
  # ============================================================================
  
  # Tags for Kubernetes AWS integration
  k8s_shared_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  
  # Tags for public subnets (for ALB)
  public_subnet_tags = merge(local.k8s_shared_tags, {
    "kubernetes.io/role/elb" = "1"
    SubnetType               = "public"
  })
  
  # Tags for private subnets (for nodes)
  private_subnet_tags = merge(local.k8s_shared_tags, {
    "kubernetes.io/role/internal-elb" = "1"
    SubnetType                        = "private"
  })
  
  # Tags for autoscaling
  autoscaler_tags = {
    "k8s.io/cluster-autoscaler/enabled"             = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
  }
  
  # ============================================================================
  # Computed values
  # ============================================================================
  
  # VPC CIDR calculations
  vpc_cidr_newbits = 8  # Creates /24 subnets from /16 VPC
  
  # Subnet CIDRs (automatically calculated)
  public_subnet_cidrs  = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, local.vpc_cidr_newbits, i + 100)]
  private_subnet_cidrs = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, local.vpc_cidr_newbits, i)]
  
  # NAT gateway count (1 for cost optimization, or one per AZ for HA)
  nat_gateway_count = var.enable_nat_gateway_ha ? length(local.azs) : 1
  
  # Security settings
  enable_private_only = var.enable_tailscale && var.enable_private_endpoint && !var.enable_public_endpoint
  
  # ============================================================================
  # Feature flags
  # ============================================================================
  
  features = {
    tailscale           = var.enable_tailscale
    private_endpoint    = var.enable_private_endpoint
    public_endpoint     = var.enable_public_endpoint
    cluster_encryption  = var.enable_cluster_encryption
    ebs_encryption      = var.enable_ebs_encryption
    cluster_logging     = var.enable_cluster_logging
    container_insights  = var.enable_container_insights
    spot_instances      = var.use_spot_instances
    nat_ha              = var.enable_nat_gateway_ha
  }
}
