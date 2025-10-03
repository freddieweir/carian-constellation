# Bootstrap Infrastructure Outputs

# ============================================================================
# S3 Buckets
# ============================================================================

output "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_state_bucket_arn" {
  description = "ARN of Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "backup_bucket" {
  description = "S3 bucket name for backups"
  value       = aws_s3_bucket.backups.id
}

output "backup_bucket_arn" {
  description = "ARN of backup bucket"
  value       = aws_s3_bucket.backups.arn
}

# ============================================================================
# DynamoDB
# ============================================================================

output "terraform_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.id
}

output "terraform_lock_table_arn" {
  description = "ARN of DynamoDB lock table"
  value       = aws_dynamodb_table.terraform_locks.arn
}

# ============================================================================
# Route53
# ============================================================================

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "route53_zone_name" {
  description = "Route53 hosted zone name"
  value       = aws_route53_zone.main.name
}

output "route53_nameservers" {
  description = "Route53 nameservers (configure these at your domain registrar)"
  value       = aws_route53_zone.main.name_servers
}

# ============================================================================
# Secrets Manager
# ============================================================================

output "secrets_manager_arns" {
  description = "ARNs of all Secrets Manager secrets"
  value = {
    authelia_session_secret   = aws_secretsmanager_secret.authelia_session_secret.arn
    authelia_storage_key      = aws_secretsmanager_secret.authelia_storage_key.arn
    grafana_admin_password    = aws_secretsmanager_secret.grafana_admin_password.arn
    openai_api_key           = aws_secretsmanager_secret.openai_api_key.arn
    anthropic_api_key        = aws_secretsmanager_secret.anthropic_api_key.arn
  }
}

output "secrets_manager_policy_arn" {
  description = "ARN of Secrets Manager read policy"
  value       = aws_iam_policy.secrets_manager_read.arn
}

# ============================================================================
# IAM
# ============================================================================

output "mfa_policy_arn" {
  description = "ARN of MFA enforcement policy"
  value       = aws_iam_policy.require_mfa.arn
}

output "automation_role_arn" {
  description = "ARN of automation role"
  value       = aws_iam_role.automation.arn
}

# ============================================================================
# Backend Configuration for Ephemeral Module
# ============================================================================

output "backend_config" {
  description = "Backend configuration for ephemeral Terraform module"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    region         = local.region
    dynamodb_table = aws_dynamodb_table.terraform_locks.id
    encrypt        = true
  }
}

output "backend_config_file_content" {
  description = "Content for backend.hcl file"
  value = <<-EOT
    bucket         = "${aws_s3_bucket.terraform_state.id}"
    region         = "${local.region}"
    dynamodb_table = "${aws_dynamodb_table.terraform_locks.id}"
    encrypt        = true
  EOT
}

# ============================================================================
# Summary
# ============================================================================

output "setup_summary" {
  description = "Summary of bootstrap setup"
  value = <<-EOT
    
    ✅ Bootstrap Complete!
    
    📦 Resources Created:
       • Terraform State: ${aws_s3_bucket.terraform_state.id}
       • Backups: ${aws_s3_bucket.backups.id}
       • State Lock: ${aws_dynamodb_table.terraform_locks.id}
       • DNS Zone: ${aws_route53_zone.main.name}
    
    🌐 DNS Setup Required:
       Configure these nameservers at your domain registrar:
       ${join("\n       ", aws_route53_zone.main.name_servers)}
    
    🔐 Next Steps:
       1. Populate secrets in AWS Secrets Manager
       2. Configure ephemeral backend: cd ../ephemeral && terraform init -backend-config=backend.hcl
       3. Deploy constellation: ./scripts/constellation-up.sh
    
    💰 Persistent Costs: ~$5.50/month
       • S3: ~$1/month
       • Route53: $0.50/month
       • Secrets Manager: ~$2/month
       • DynamoDB: Pay-per-request (minimal)
  EOT
}
