# ============================================================================
# Outputs - Ephemeral Infrastructure Information
# ============================================================================

# ============================================================================
# Cluster Information
# ============================================================================

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_version" {
  description = "Kubernetes version of the cluster"
  value       = module.eks.cluster_version
}

output "cluster_platform_version" {
  description = "Platform version for the cluster"
  value       = module.eks.cluster_platform_version
}

output "cluster_status" {
  description = "Status of the cluster"
  value       = module.eks.cluster_status
}

# ============================================================================
# OIDC Provider (for IRSA)
# ============================================================================

output "oidc_provider" {
  description = "OIDC provider URL for IRSA"
  value       = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = try(module.eks.cluster_oidc_issuer_url, null)
}

# ============================================================================
# Node Groups
# ============================================================================

output "node_groups" {
  description = "EKS node groups"
  value       = module.eks.eks_managed_node_groups
  sensitive   = true
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

# ============================================================================
# VPC Information
# ============================================================================

output "vpc_id" {
  description = "VPC ID where resources are deployed"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

# ============================================================================
# Tailscale Relay Information
# ============================================================================

output "tailscale_relay_instance_id" {
  description = "Instance ID of the Tailscale relay"
  value       = aws_instance.tailscale_relay.id
}

output "tailscale_relay_public_ip" {
  description = "Public IP address of Tailscale relay"
  value       = aws_instance.tailscale_relay.public_ip
}

output "tailscale_relay_private_ip" {
  description = "Private IP address of Tailscale relay"
  value       = aws_instance.tailscale_relay.private_ip
}

output "tailscale_relay_security_group_id" {
  description = "Security group ID for Tailscale relay"
  value       = aws_security_group.tailscale_relay.id
}

output "tailscale_relay_eip" {
  description = "Elastic IP for Tailscale relay (if enabled)"
  value       = var.use_tailscale_eip ? aws_eip.tailscale_relay[0].public_ip : null
}

# ============================================================================
# Security Resources
# ============================================================================

output "eks_kms_key_id" {
  description = "KMS key ID for EKS cluster encryption"
  value       = aws_kms_key.eks.key_id
}

output "eks_kms_key_arn" {
  description = "KMS key ARN for EKS cluster encryption"
  value       = aws_kms_key.eks.arn
}

output "ebs_kms_key_id" {
  description = "KMS key ID for EBS encryption"
  value       = aws_kms_key.ebs.key_id
}

output "ebs_kms_key_arn" {
  description = "KMS key ARN for EBS encryption"
  value       = aws_kms_key.ebs.arn
}

output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = aws_security_group.alb.id
}

# ============================================================================
# CloudWatch Log Groups
# ============================================================================

output "eks_cluster_log_group_name" {
  description = "CloudWatch log group name for EKS cluster logs"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}

output "application_log_group_name" {
  description = "CloudWatch log group name for application logs"
  value       = aws_cloudwatch_log_group.application.name
}

# ============================================================================
# Connection Commands
# ============================================================================

output "kubeconfig_command" {
  description = "Command to update kubeconfig for cluster access"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "kubectl_verify_command" {
  description = "Command to verify cluster access"
  value       = "kubectl get nodes"
}

output "ssm_connect_command" {
  description = "Command to connect to Tailscale relay via SSM"
  value       = "aws ssm start-session --target ${aws_instance.tailscale_relay.id} --region ${var.aws_region}"
}

# ============================================================================
# Cost Estimation
# ============================================================================

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (approximate)"
  value = {
    eks_control_plane = "$73 (per cluster)"
    eks_nodes         = "$${var.node_desired_size * 30 * 0.0416} (t3.medium spot, approximate)"
    nat_gateway       = "$32.40 (per gateway)"
    ebs_volumes       = "$${var.node_desired_size * var.node_disk_size * 0.08} (gp3, approximate)"
    tailscale_relay   = "$${var.tailscale_instance_type == "t3.micro" ? 10.08 : 20.16} (approximate)"
    data_transfer     = "Variable (depends on usage)"
    total_minimum     = "~$150-200/month (minimum configuration)"
  }
}

# ============================================================================
# Configuration Summary
# ============================================================================

output "configuration_summary" {
  description = "Summary of infrastructure configuration"
  value = {
    project_name      = var.project_name
    environment       = var.environment
    region            = var.aws_region
    cluster_name      = local.cluster_name
    cluster_version   = var.kubernetes_version
    vpc_cidr          = var.vpc_cidr
    node_count        = "${var.node_min_size}-${var.node_max_size} (desired: ${var.node_desired_size})"
    node_type         = var.node_instance_types
    node_capacity     = var.node_capacity_type
    tailscale_enabled = true
  }
}

# ============================================================================
# Post-Deployment Instructions
# ============================================================================

output "next_steps" {
  description = "Post-deployment instructions"
  value = <<-EOT
  
  🎉 Infrastructure Deployment Complete!
  
  📋 Next Steps:
  
  1. Configure kubectl access:
     ${module.eks.cluster_endpoint != "" ? "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}" : "Waiting for cluster..."}
  
  2. Verify cluster access:
     kubectl get nodes
     kubectl get pods --all-namespaces
  
  3. Access Tailscale relay:
     - Public IP: ${aws_instance.tailscale_relay.public_ip}
     - Connect via SSM: aws ssm start-session --target ${aws_instance.tailscale_relay.id}
     - Check setup: ssh to relay and view /root/tailscale-ready
  
  4. Approve Tailscale subnet routes:
     - Visit: https://login.tailscale.com/admin/machines
     - Find: constellation-relay-${var.aws_region}
     - Enable subnet routing for VPC CIDR: ${module.vpc.vpc_cidr_block}
  
  5. Install persistent infrastructure (ALB, External Secrets, etc.):
     cd ../persistent
     terraform init
     terraform plan
     terraform apply
  
  6. Deploy applications:
     cd ../../kubernetes
     kubectl apply -f namespaces/
     kubectl apply -f secrets/ (after configuring External Secrets)
     kubectl apply -f workloads/
  
  📊 Cluster Info:
  - Name: ${module.eks.cluster_name}
  - Endpoint: ${module.eks.cluster_endpoint}
  - Version: ${module.eks.cluster_version}
  - Status: ${module.eks.cluster_status}
  
  🔒 Security:
  - EKS secrets encrypted with KMS: ${aws_kms_key.eks.key_id}
  - EBS volumes encrypted with KMS: ${aws_kms_key.ebs.key_id}
  - IMDSv2 required on all instances
  - VPC endpoints enabled for AWS services
  
  💰 Estimated Monthly Cost: ~$150-200 (minimum configuration)
  
  📚 Documentation:
  - Architecture: ../docs/architecture.md
  - Operations: ../docs/operations.md
  - Troubleshooting: ../docs/troubleshooting.md
  
  EOT
}

# ============================================================================
# Resource Tags
# ============================================================================

output "common_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}

# ============================================================================
# AWS Account Information
# ============================================================================

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_caller_arn" {
  description = "ARN of the caller identity"
  value       = data.aws_caller_identity.current.arn
}
