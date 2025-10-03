# Variables for Persistent Infrastructure

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
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
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
  description = "Primary domain name (e.g., example.com)"
  type        = string
}

# ============================================================================
# AWS Load Balancer Controller
# ============================================================================

variable "enable_alb_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "alb_controller_version" {
  description = "Version of AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.6.2"
}

# ============================================================================
# External Secrets Operator
# ============================================================================

variable "enable_external_secrets" {
  description = "Enable External Secrets Operator"
  type        = bool
  default     = true
}

variable "external_secrets_version" {
  description = "Version of External Secrets Operator Helm chart"
  type        = string
  default     = "0.9.9"
}

variable "secrets_backend" {
  description = "Secrets backend to use (aws-secrets-manager, 1password)"
  type        = string
  default     = "aws-secrets-manager"
  validation {
    condition     = contains(["aws-secrets-manager", "1password"], var.secrets_backend)
    error_message = "Secrets backend must be aws-secrets-manager or 1password."
  }
}

# ============================================================================
# cert-manager
# ============================================================================

variable "enable_cert_manager" {
  description = "Enable cert-manager for TLS certificate management"
  type        = bool
  default     = true
}

variable "cert_manager_version" {
  description = "Version of cert-manager Helm chart"
  type        = string
  default     = "v1.13.2"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
}

variable "letsencrypt_environment" {
  description = "Let's Encrypt environment (staging or production)"
  type        = string
  default     = "staging"
  validation {
    condition     = contains(["staging", "production"], var.letsencrypt_environment)
    error_message = "Let's Encrypt environment must be staging or production."
  }
}

# ============================================================================
# Monitoring Stack (Prometheus & Grafana)
# ============================================================================

variable "enable_monitoring" {
  description = "Enable Prometheus and Grafana monitoring stack"
  type        = bool
  default     = true
}

variable "prometheus_retention_days" {
  description = "Prometheus data retention in days"
  type        = number
  default     = 15
}

variable "prometheus_storage_size" {
  description = "Prometheus storage size (e.g., 10Gi, 50Gi)"
  type        = string
  default     = "10Gi"
}

variable "grafana_admin_password" {
  description = "Grafana admin password (stored in Kubernetes secret)"
  type        = string
  sensitive   = true
}

variable "enable_grafana_persistence" {
  description = "Enable persistent storage for Grafana"
  type        = bool
  default     = true
}

variable "grafana_storage_size" {
  description = "Grafana storage size (e.g., 5Gi, 10Gi)"
  type        = string
  default     = "5Gi"
}

# ============================================================================
# Ingress Configuration
# ============================================================================

variable "enable_ingress_nginx" {
  description = "Enable NGINX Ingress Controller (alternative to ALB)"
  type        = bool
  default     = false
}

variable "ingress_class" {
  description = "Ingress class to use (alb or nginx)"
  type        = string
  default     = "alb"
  validation {
    condition     = contains(["alb", "nginx"], var.ingress_class)
    error_message = "Ingress class must be alb or nginx."
  }
}

# ============================================================================
# Storage Configuration
# ============================================================================

variable "enable_ebs_storage_class" {
  description = "Create EBS storage class for persistent volumes"
  type        = bool
  default     = true
}

variable "enable_efs_storage_class" {
  description = "Create EFS storage class for shared volumes"
  type        = bool
  default     = false
}

variable "efs_file_system_id" {
  description = "Existing EFS file system ID (if using EFS)"
  type        = string
  default     = ""
}

# ============================================================================
# Metrics Server
# ============================================================================

variable "enable_metrics_server" {
  description = "Enable Kubernetes Metrics Server (required for HPA)"
  type        = bool
  default     = true
}

variable "metrics_server_version" {
  description = "Version of Metrics Server Helm chart"
  type        = string
  default     = "3.11.0"
}

# ============================================================================
# Cluster Autoscaler
# ============================================================================

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler for automatic node scaling"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_version" {
  description = "Version of Cluster Autoscaler Helm chart"
  type        = string
  default     = "9.29.3"
}

# ============================================================================
# Reloader
# ============================================================================

variable "enable_reloader" {
  description = "Enable Reloader to auto-restart pods on ConfigMap/Secret changes"
  type        = bool
  default     = true
}

variable "reloader_version" {
  description = "Version of Reloader Helm chart"
  type        = string
  default     = "1.0.44"
}

# ============================================================================
# Node Problem Detector
# ============================================================================

variable "enable_node_problem_detector" {
  description = "Enable Node Problem Detector for node health monitoring"
  type        = bool
  default     = false
}
