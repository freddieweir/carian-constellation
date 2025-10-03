# ============================================================================
# Outputs - Persistent Infrastructure Information
# ============================================================================

# ============================================================================
# Cluster Information (from Ephemeral State)
# ============================================================================

output "cluster_name" {
  description = "EKS cluster name"
  value       = local.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = data.aws_eks_cluster.cluster.endpoint
}

# ============================================================================
# AWS Load Balancer Controller
# ============================================================================

output "alb_controller_enabled" {
  description = "Whether AWS Load Balancer Controller is enabled"
  value       = var.enable_alb_controller
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = var.enable_alb_controller ? aws_iam_role.alb_controller[0].arn : null
}

# ============================================================================
# External Secrets Operator
# ============================================================================

output "external_secrets_enabled" {
  description = "Whether External Secrets Operator is enabled"
  value       = var.enable_external_secrets
}

output "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  value       = var.enable_external_secrets && var.secrets_backend == "aws-secrets-manager" ? aws_iam_role.external_secrets[0].arn : null
}

output "secrets_backend" {
  description = "Secrets backend in use"
  value       = var.secrets_backend
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore"
  value       = var.secrets_backend == "aws-secrets-manager" ? "aws-secrets-manager" : "onepassword-connect"
}

# ============================================================================
# cert-manager
# ============================================================================

output "cert_manager_enabled" {
  description = "Whether cert-manager is enabled"
  value       = var.enable_cert_manager
}

output "cert_manager_role_arn" {
  description = "IAM role ARN for cert-manager Route53 access"
  value       = var.enable_cert_manager ? aws_iam_role.cert_manager[0].arn : null
}

output "letsencrypt_environment" {
  description = "Let's Encrypt environment (staging or production)"
  value       = var.letsencrypt_environment
}

output "letsencrypt_cluster_issuer" {
  description = "Default Let's Encrypt ClusterIssuer name"
  value       = var.letsencrypt_environment == "production" ? "letsencrypt-production" : "letsencrypt-staging"
}

# ============================================================================
# Monitoring Stack
# ============================================================================

output "monitoring_enabled" {
  description = "Whether monitoring stack is enabled"
  value       = var.enable_monitoring
}

output "grafana_url" {
  description = "Grafana URL"
  value       = var.enable_monitoring ? "https://grafana.${var.domain_name}" : null
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = var.enable_monitoring ? "https://prometheus.${var.domain_name}" : null
}

output "grafana_admin_user" {
  description = "Grafana admin username"
  value       = var.enable_monitoring ? "admin" : null
}

# ============================================================================
# Storage Classes
# ============================================================================

output "default_storage_class" {
  description = "Default storage class name"
  value       = var.enable_ebs_storage_class ? "gp3" : null
}

output "available_storage_classes" {
  description = "List of available storage classes"
  value = var.enable_ebs_storage_class ? [
    "gp3 (default)",
    "gp3-high-iops",
    "io2-database",
    "gp3-retain",
    var.enable_efs_storage_class && var.efs_file_system_id != "" ? "efs" : null
  ] : []
}

# ============================================================================
# Cluster Components
# ============================================================================

output "metrics_server_enabled" {
  description = "Whether Metrics Server is enabled"
  value       = var.enable_metrics_server
}

output "cluster_autoscaler_enabled" {
  description = "Whether Cluster Autoscaler is enabled"
  value       = var.enable_cluster_autoscaler
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = var.enable_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].arn : null
}

output "reloader_enabled" {
  description = "Whether Reloader is enabled"
  value       = var.enable_reloader
}

# ============================================================================
# Ingress Configuration
# ============================================================================

output "ingress_class" {
  description = "Ingress class in use"
  value       = var.ingress_class
}

# ============================================================================
# Next Steps
# ============================================================================

output "next_steps" {
  description = "Post-deployment instructions for persistent infrastructure"
  value = <<-EOT
  
  🎉 Persistent Infrastructure Deployment Complete!
  
  📋 What Was Deployed:
  
  ${var.enable_alb_controller ? "✅ AWS Load Balancer Controller - Ready for Ingress resources" : "⏭️  ALB Controller - Disabled"}
  ${var.enable_external_secrets ? "✅ External Secrets Operator - Secret sync from ${var.secrets_backend}" : "⏭️  External Secrets - Disabled"}
  ${var.enable_cert_manager ? "✅ cert-manager - Automatic TLS certificates (${var.letsencrypt_environment})" : "⏭️  cert-manager - Disabled"}
  ${var.enable_monitoring ? "✅ Monitoring Stack - Prometheus & Grafana" : "⏭️  Monitoring - Disabled"}
  ${var.enable_metrics_server ? "✅ Metrics Server - HPA and kubectl top enabled" : "⏭️  Metrics Server - Disabled"}
  ${var.enable_cluster_autoscaler ? "✅ Cluster Autoscaler - Automatic node scaling" : "⏭️  Cluster Autoscaler - Disabled"}
  ${var.enable_reloader ? "✅ Reloader - Auto-restart on config changes" : "⏭️  Reloader - Disabled"}
  ${var.enable_ebs_storage_class ? "✅ EBS Storage Classes - gp3, gp3-high-iops, io2-database" : "⏭️  Storage Classes - Using defaults"}
  
  🌐 Access Points:
  ${var.enable_monitoring ? "  - Grafana: https://grafana.${var.domain_name}" : ""}
  ${var.enable_monitoring ? "    Username: admin" : ""}
  ${var.enable_monitoring ? "    Password: [set in terraform.tfvars]" : ""}
  ${var.enable_monitoring ? "" : ""}
  ${var.enable_monitoring ? "  - Prometheus: https://prometheus.${var.domain_name}" : ""}
  
  🔐 Security Configuration:
  ${var.enable_cert_manager ? "  - TLS: Let's Encrypt ${var.letsencrypt_environment}" : "  - TLS: Manual certificate management"}
  ${var.enable_external_secrets ? "  - Secrets: ${var.secrets_backend}" : "  - Secrets: Kubernetes native"}
  ${var.enable_external_secrets && var.secrets_backend == "aws-secrets-manager" ? "  - ClusterSecretStore: aws-secrets-manager" : ""}
  
  📊 Monitoring:
  ${var.enable_metrics_server ? "  - Metrics Server: kubectl top nodes/pods" : ""}
  ${var.enable_monitoring ? "  - Prometheus retention: ${var.prometheus_retention_days} days" : ""}
  ${var.enable_monitoring ? "  - Prometheus storage: ${var.prometheus_storage_size}" : ""}
  
  📦 Storage:
  ${var.enable_ebs_storage_class ? "  - Default storage class: gp3 (encrypted)" : ""}
  ${var.enable_ebs_storage_class ? "  - High performance: gp3-high-iops" : ""}
  ${var.enable_ebs_storage_class ? "  - Database workloads: io2-database" : ""}
  ${var.enable_efs_storage_class && var.efs_file_system_id != "" ? "  - Shared storage: efs" : ""}
  
  🚀 Next Steps:
  
  1. Verify all components are running:
     kubectl get pods --all-namespaces
  
  2. Check Helm releases:
     helm list --all-namespaces
  
  ${var.enable_monitoring ? "3. Access Grafana:\n     open https://grafana.${var.domain_name}\n" : ""}
  
  ${var.enable_external_secrets && var.secrets_backend == "aws-secrets-manager" ? "4. Create secrets in AWS Secrets Manager:\n     aws secretsmanager create-secret \\\n       --name ${var.project_name}/your-app/db-password \\\n       --secret-string \"your-secure-password\"\n" : ""}
  
  ${var.enable_cert_manager ? "5. Create TLS certificates:\n     Certificates will be issued automatically via Ingress annotations\n" : ""}
  
  6. Deploy your applications:
     cd ../../kubernetes
     kubectl apply -f namespaces/
     kubectl apply -f applications/
  
  📚 Documentation:
  - External Secrets: https://external-secrets.io/
  - cert-manager: https://cert-manager.io/
  - Prometheus: https://prometheus.io/
  - Grafana: https://grafana.com/
  
  💡 Tips:
  ${var.enable_external_secrets ? "- Use ExternalSecret resources to sync secrets from ${var.secrets_backend}" : ""}
  ${var.enable_cert_manager ? "- Add cert-manager.io/cluster-issuer annotation to Ingress for TLS" : ""}
  ${var.enable_cluster_autoscaler ? "- Cluster will auto-scale based on pod resource requests" : ""}
  ${var.enable_reloader ? "- Add reloader.stakater.com/auto: \"true\" to Deployments for auto-restart" : ""}
  
  EOT
}

# ============================================================================
# Configuration Summary
# ============================================================================

output "configuration_summary" {
  description = "Summary of persistent infrastructure configuration"
  value = {
    project_name        = var.project_name
    environment         = var.environment
    cluster_name        = local.cluster_name
    region              = var.aws_region
    domain              = var.domain_name
    alb_controller      = var.enable_alb_controller
    external_secrets    = var.enable_external_secrets
    secrets_backend     = var.secrets_backend
    cert_manager        = var.enable_cert_manager
    letsencrypt         = var.letsencrypt_environment
    monitoring          = var.enable_monitoring
    metrics_server      = var.enable_metrics_server
    cluster_autoscaler  = var.enable_cluster_autoscaler
    reloader            = var.enable_reloader
    ingress_class       = var.ingress_class
  }
}
