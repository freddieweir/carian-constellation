# Variables for Ephemeral Infrastructure

# ============================================================================
# Project Configuration
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "carian-constellation"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

# ============================================================================
# AWS Configuration
# ============================================================================

variable "aws_region" {
  description = "AWS region for ephemeral resources"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "constellation"
}

# ============================================================================
# Owner Information
# ============================================================================

variable "owner_name" {
  description = "Owner name for resource tagging"
  type        = string
  default     = "stalheim"
}

variable "owner_email" {
  description = "Owner email for resource tagging"
  type        = string
}

variable "github_username" {
  description = "GitHub username for repository tagging"
  type        = string
}

variable "domain_name" {
  description = "Your domain name (e.g., example.com)"
  type        = string
}

# ============================================================================
# Networking
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use (leave empty for auto-selection)"
  type        = list(string)
  default     = []
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (cost optimization)"
  type        = bool
  default     = true
}

# ============================================================================
# EKS Configuration
# ============================================================================

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "cluster_version" {
  description = "(Deprecated - use kubernetes_version) Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 4
}

variable "node_disk_size" {
  description = "Disk size for nodes (GB)"
  type        = number
  default     = 20
}

variable "use_spot_instances" {
  description = "Use spot instances for additional cost savings"
  type        = bool
  default     = false
}

variable "node_capacity_type" {
  description = "Type of capacity for nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "Capacity type must be ON_DEMAND or SPOT."
  }
}

# ============================================================================
# Security - Tailscale
# ============================================================================

variable "enable_tailscale" {
  description = "Enable Tailscale subnet router"
  type        = bool
  default     = true
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key (ephemeral, reusable)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "my_tailscale_ip" {
  description = "Your Tailscale device IP (100.x.x.x)"
  type        = string
  default     = ""
}

variable "tailscale_instance_type" {
  description = "Instance type for Tailscale relay"
  type        = string
  default     = "t3.micro"
}

variable "use_tailscale_eip" {
  description = "Allocate an Elastic IP for the Tailscale relay (for stable IP address)"
  type        = bool
  default     = false
}

variable "allowed_public_access_cidrs" {
  description = "CIDR blocks allowed to access EKS cluster endpoint publicly"
  type        = list(string)
  default     = []
}

# ============================================================================
# Security - General
# ============================================================================

variable "enable_private_endpoint" {
  description = "Enable private EKS endpoint only (recommended with Tailscale)"
  type        = bool
  default     = true
}

variable "enable_public_endpoint" {
  description = "Enable public EKS endpoint (disable with Tailscale)"
  type        = bool
  default     = false
}

variable "my_public_ip" {
  description = "Your public IP for whitelisting (if not using Tailscale)"
  type        = string
  default     = ""
}

variable "enable_cluster_encryption" {
  description = "Enable encryption for EKS secrets at rest"
  type        = bool
  default     = true
}

variable "enable_ebs_encryption" {
  description = "Enable encryption for EBS volumes"
  type        = bool
  default     = true
}

# ============================================================================
# Monitoring & Logging
# ============================================================================

variable "enable_cluster_logging" {
  description = "Enable EKS control plane logging"
  type        = bool
  default     = true
}

variable "cluster_log_types" {
  description = "EKS control plane log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# ============================================================================
# Cost Optimization
# ============================================================================

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights (costs extra)"
  type        = bool
  default     = false
}

variable "enable_nat_gateway_ha" {
  description = "Enable NAT gateway high availability (one per AZ, costs more)"
  type        = bool
  default     = false
}
