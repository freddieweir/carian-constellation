# ============================================================================
# cert-manager
# ============================================================================
# Automatic TLS certificate management using Let's Encrypt

# ============================================================================
# Namespace for cert-manager
# ============================================================================

resource "kubernetes_namespace" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  metadata {
    name = "cert-manager"

    labels = {
      name                                 = "cert-manager"
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "restricted"
      "cert-manager.io/disable-validation" = "true"
    }
  }
}

# ============================================================================
# Helm Release for cert-manager
# ============================================================================

resource "helm_release" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_version
  namespace  = kubernetes_namespace.cert_manager[0].metadata[0].name

  # Install CRDs
  set {
    name  = "installCRDs"
    value = "true"
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

  # CAInjector resource limits
  set {
    name  = "cainjector.resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "cainjector.resources.limits.memory"
    value = "128Mi"
  }

  set {
    name  = "cainjector.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "cainjector.resources.requests.memory"
    value = "64Mi"
  }

  # Prometheus metrics
  set {
    name  = "prometheus.enabled"
    value = var.enable_monitoring ? "true" : "false"
  }

  depends_on = [
    kubernetes_namespace.cert_manager
  ]
}

# ============================================================================
# Let's Encrypt Staging ClusterIssuer
# ============================================================================

resource "kubectl_manifest" "letsencrypt_staging" {
  count = var.enable_cert_manager && var.letsencrypt_environment == "staging" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-staging"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      acme = {
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-staging"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = var.ingress_class
              }
            }
          }
        ]
      }
    }
  })

  depends_on = [
    helm_release.cert_manager
  ]
}

# ============================================================================
# Let's Encrypt Production ClusterIssuer
# ============================================================================

resource "kubectl_manifest" "letsencrypt_production" {
  count = var.enable_cert_manager && var.letsencrypt_environment == "production" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-production"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-production"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = var.ingress_class
              }
            }
          }
        ]
      }
    }
  })

  depends_on = [
    helm_release.cert_manager
  ]
}

# ============================================================================
# DNS01 ClusterIssuer for Route53 (Wildcard Certificates)
# ============================================================================

# IAM Role for cert-manager Route53 access
data "aws_iam_policy_document" "cert_manager_assume_role" {
  count = var.enable_cert_manager ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${data.terraform_remote_state.ephemeral.outputs.oidc_provider}:sub"
      values   = ["system:serviceaccount:cert-manager:cert-manager"]
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

resource "aws_iam_role" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name               = "${local.cluster_name}-cert-manager"
  assume_role_policy = data.aws_iam_policy_document.cert_manager_assume_role[0].json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-cert-manager"
    }
  )
}

# IAM Policy for Route53 access
resource "aws_iam_policy" "cert_manager_route53" {
  count = var.enable_cert_manager ? 1 : 0

  name        = "${local.cluster_name}-cert-manager-route53"
  description = "IAM policy for cert-manager to manage Route53 records for DNS01 challenge"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:GetChange"
        ]
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZonesByName",
          "route53:ListHostedZones"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cert_manager_route53" {
  count = var.enable_cert_manager ? 1 : 0

  role       = aws_iam_role.cert_manager[0].name
  policy_arn = aws_iam_policy.cert_manager_route53[0].arn
}

# Service account with IAM role annotation
resource "kubernetes_service_account" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  metadata {
    name      = "cert-manager"
    namespace = kubernetes_namespace.cert_manager[0].metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cert_manager[0].arn
    }

    labels = {
      "app.kubernetes.io/name"       = "cert-manager"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# DNS01 ClusterIssuer using Route53
resource "kubectl_manifest" "letsencrypt_dns01" {
  count = var.enable_cert_manager ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-dns01"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      acme = {
        server = var.letsencrypt_environment == "production" ? "https://acme-v02.api.letsencrypt.org/directory" : "https://acme-staging-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-dns01"
        }
        solvers = [
          {
            dns01 = {
              route53 = {
                region = var.aws_region
              }
            }
            selector = {
              dnsZones = [
                var.domain_name
              ]
            }
          }
        ]
      }
    }
  })

  depends_on = [
    helm_release.cert_manager,
    kubernetes_service_account.cert_manager
  ]
}
