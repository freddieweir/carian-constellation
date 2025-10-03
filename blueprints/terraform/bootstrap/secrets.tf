# AWS Secrets Manager Configuration

# ============================================================================
# Secret Placeholders
# ============================================================================

# These secrets will be populated manually after bootstrap
# or via the CLI in the deployment guide

resource "aws_secretsmanager_secret" "authelia_session_secret" {
  name                    = "${local.project_prefix}/authelia/session-secret"
  description             = "Authelia session encryption secret"
  recovery_window_in_days = 7
  
  tags = merge(local.common_tags, {
    Name      = "Authelia Session Secret"
    Service   = "authentication"
    Component = "authelia"
    Purpose   = "session-encryption"
    Critical  = "true"
  })
}

resource "aws_secretsmanager_secret" "authelia_storage_key" {
  name                    = "${local.project_prefix}/authelia/storage-encryption-key"
  description             = "Authelia storage encryption key"
  recovery_window_in_days = 7
  
  tags = merge(local.common_tags, {
    Name      = "Authelia Storage Key"
    Service   = "authentication"
    Component = "authelia"
    Purpose   = "storage-encryption"
    Critical  = "true"
  })
}

resource "aws_secretsmanager_secret" "grafana_admin_password" {
  name                    = "${local.project_prefix}/grafana/admin-password"
  description             = "Grafana admin password"
  recovery_window_in_days = 7
  
  tags = merge(local.common_tags, {
    Name      = "Grafana Admin Password"
    Service   = "monitoring"
    Component = "grafana"
    Purpose   = "admin-access"
    Critical  = "true"
  })
}

resource "aws_secretsmanager_secret" "openai_api_key" {
  name                    = "${local.project_prefix}/api-keys/openai"
  description             = "OpenAI API key for Open-WebUI"
  recovery_window_in_days = 7
  
  tags = merge(local.common_tags, {
    Name      = "OpenAI API Key"
    Service   = "ai-services"
    Component = "open-webui"
    Purpose   = "llm-access"
    Vendor    = "openai"
  })
}

resource "aws_secretsmanager_secret" "anthropic_api_key" {
  name                    = "${local.project_prefix}/api-keys/anthropic"
  description             = "Anthropic API key for Open-WebUI"
  recovery_window_in_days = 7
  
  tags = merge(local.common_tags, {
    Name      = "Anthropic API Key"
    Service   = "ai-services"
    Component = "open-webui"
    Purpose   = "llm-access"
    Vendor    = "anthropic"
  })
}

# ============================================================================
# Secrets Manager Access Policy for External Secrets Operator
# ============================================================================

# This policy will be attached to the IRSA role in ephemeral infrastructure
resource "aws_iam_policy" "secrets_manager_read" {
  name        = "${local.project_prefix}-secrets-manager-read"
  description = "Allow External Secrets Operator to read secrets"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${local.project_prefix}/*"
      }
    ]
  })
  
  tags = local.common_tags
}
