# ============================================================================
# External Secrets Operator
# ============================================================================
# Syncs secrets from external secret stores (AWS Secrets Manager, 1Password, etc.)
# into Kubernetes Secrets

# ============================================================================
# IAM Role for External Secrets Operator (IRSA)
# ============================================================================

data "aws_iam_policy_document" "external_secrets_assume_role" {
  count = var.enable_external_secrets && var.secrets_backend == "aws-secrets-manager" ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${data.terraform_remote_state.ephemeral.outputs.oidc_provider}:sub"
      values   = ["system:serviceaccount:external-secrets:external-secrets"]
    }

    condition {
      test     = "StringEquals"
      variable = "${data.terraform_remote_state.ephemeral.outputs.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [data.terraform_remote_state.ephemeral.outputs.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  count = var.enable_external_secrets && var.secrets_backend == "aws-secrets-manager" ? 1 : 0

  name               = "${local.cluster_name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role[0].json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-external-secrets"
    }
  )
}

# ============================================================================
# IAM Policy for External Secrets Operator (AWS Secrets Manager)
# ============================================================================

resource "aws_iam_policy" "external_secrets" {
  count = var.enable_external_secrets && var.secrets_backend == "aws-secrets-manager" ? 1 : 0

  name        = "${local.cluster_name}-external-secrets-policy"
  description = "IAM policy for External Secrets Operator to access AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.project_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  count = var.enable_external_secrets && var.secrets_backend == "aws-secrets-manager" ? 1 : 0

  role       = aws_iam_role.external_secrets[0].name
  policy_arn = aws_iam_policy.external_secrets[0].arn
}

# ============================================================================
# Namespace for External Secrets
# ============================================================================

resource "kubernetes_namespace" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  metadata {
    name = "external-secrets"

    labels = {
      name                               = "external-secrets"
      "app.kubernetes.io/managed-by"     = "terraform"
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

# ============================================================================
# Kubernetes Service Account for External Secrets
# ============================================================================

resource "kubernetes_service_account" "external_secrets" {
  count = var.enable_external_secrets && var.secrets_backend == "aws-secrets-manager" ? 1 : 0

  metadata {
    name      = "external-secrets"
    namespace = kubernetes_namespace.external_secrets[0].metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.external_secrets[0].arn
    }

    labels = {
      "app.kubernetes.io/name"       = "external-secrets"
      "app.kubernetes.io/component"  = "controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# ============================================================================
# Helm Release for External Secrets Operator
# ============================================================================

resource "helm_release" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.external_secrets_version
  namespace  = kubernetes_namespace.external_secrets[0].metadata[0].name

  # Use existing service account for AWS Secrets Manager
  dynamic "set" {
    for_each = var.secrets_backend == "aws-secrets-manager" ? [1] : []
    content {
      name  = "serviceAccount.create"
      value = "false"
    }
  }

  dynamic "set" {
    for_each = var.secrets_backend == "aws-secrets-manager" ? [1] : []
    content {
      name  = "serviceAccount.name"
      value = kubernetes_service_account.external_secrets[0].metadata[0].name
    }
  }

  # Resource limits
  set {
    name  = "resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "resources.limits.memory"
    value = "128Mi"
  }

  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  # Webhook resource limits
  set {
    name  = "webhook.resources.limits.cpu"
    value = "50m"
  }

  set {
    name  = "webhook.resources.limits.memory"
    value = "64Mi"
  }

  set {
    name  = "webhook.resources.requests.cpu"
    value = "25m"
  }

  set {
    name  = "webhook.resources.requests.memory"
    value = "32Mi"
  }

  # Cert controller resource limits
  set {
    name  = "certController.resources.limits.cpu"
    value = "50m"
  }

  set {
    name  = "certController.resources.limits.memory"
    value = "64Mi"
  }

  set {
    name  = "certController.resources.requests.cpu"
    value = "25m"
  }

  set {
    name  = "certController.resources.requests.memory"
    value = "32Mi"
  }

  depends_on = [
    kubernetes_namespace.external_secrets
  ]
}

# ============================================================================
# ClusterSecretStore for AWS Secrets Manager
# ============================================================================

resource "kubectl_manifest" "cluster_secret_store_aws" {
  count = var.enable_external_secrets && var.secrets_backend == "aws-secrets-manager" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secrets-manager"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = kubernetes_service_account.external_secrets[0].metadata[0].name
                namespace = kubernetes_namespace.external_secrets[0].metadata[0].name
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    helm_release.external_secrets
  ]
}

# ============================================================================
# ClusterSecretStore for 1Password Connect
# ============================================================================

resource "kubectl_manifest" "cluster_secret_store_1password" {
  count = var.enable_external_secrets && var.secrets_backend == "1password" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "onepassword-connect"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      provider = {
        onepassword = {
          connectHost = "http://onepassword-connect.onepassword-connect:8080"
          vaults = {
            "Carian Constellation" = 1
          }
          auth = {
            secretRef = {
              connectToken = {
                name      = "onepassword-token"
                namespace = "onepassword-connect"
                key       = "token"
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    helm_release.external_secrets
  ]
}
