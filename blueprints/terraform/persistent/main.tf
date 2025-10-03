# Carian Constellation - Persistent Infrastructure
# Long-running components that persist across ephemeral cluster lifecycles

terraform {
  required_version = ">= 1.5"
  
  # Remote S3 backend (configured via backend.hcl)
  backend "s3" {
    key = "persistent/terraform.tfstate"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

# ============================================================================
# Data Sources - Import Ephemeral Infrastructure State
# ============================================================================

data "terraform_remote_state" "ephemeral" {
  backend = "s3"
  
  config = {
    bucket = var.terraform_state_bucket
    key    = "ephemeral/terraform.tfstate"
    region = var.aws_region
  }
}

# ============================================================================
# AWS Provider
# ============================================================================

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

# ============================================================================
# Kubernetes Provider
# ============================================================================

data "aws_eks_cluster" "cluster" {
  name = local.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = local.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# ============================================================================
# Helm Provider
# ============================================================================

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# ============================================================================
# Kubectl Provider
# ============================================================================

provider "kubectl" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

# ============================================================================
# Local Values
# ============================================================================

locals {
  cluster_name = data.terraform_remote_state.ephemeral.outputs.cluster_name
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Component   = "Persistent"
    Repository  = "https://github.com/${var.github_username}/carian-constellation"
    Owner       = var.owner_name
    CostCenter  = "Infrastructure"
  }
}
