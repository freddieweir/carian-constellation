# ============================================================================
# Monitoring Stack - Prometheus & Grafana
# ============================================================================
# Complete monitoring solution using kube-prometheus-stack

# ============================================================================
# Namespace for Monitoring
# ============================================================================

resource "kubernetes_namespace" "monitoring" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name = "monitoring"

    labels = {
      name                               = "monitoring"
      "app.kubernetes.io/managed-by"     = "terraform"
      "pod-security.kubernetes.io/enforce" = "baseline"
    }
  }
}

# ============================================================================
# StorageClass for Prometheus (if using EBS)
# ============================================================================

resource "kubernetes_storage_class" "prometheus_gp3" {
  count = var.enable_monitoring && var.enable_ebs_storage_class ? 1 : 0

  metadata {
    name = "prometheus-gp3"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Retain"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }
}

# ============================================================================
# Helm Release for kube-prometheus-stack
# ============================================================================

resource "helm_release" "kube_prometheus_stack" {
  count = var.enable_monitoring ? 1 : 0

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "54.0.0"
  namespace  = kubernetes_namespace.monitoring[0].metadata[0].name

  # Timeout for initial deployment (includes CRD installation)
  timeout = 600

  # ============================================================================
  # Prometheus Configuration
  # ============================================================================

  # Prometheus retention
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "${var.prometheus_retention_days}d"
  }

  # Prometheus storage
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = var.enable_ebs_storage_class ? kubernetes_storage_class.prometheus_gp3[0].metadata[0].name : "gp3"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]"
    value = "ReadWriteOnce"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.prometheus_storage_size
  }

  # Prometheus resource limits
  set {
    name  = "prometheus.prometheusSpec.resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.limits.memory"
    value = "2Gi"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.cpu"
    value = "250m"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = "1Gi"
  }

  # Enable service monitors for all namespaces
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  # ============================================================================
  # Grafana Configuration
  # ============================================================================

  # Grafana admin password
  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  # Grafana persistence
  set {
    name  = "grafana.persistence.enabled"
    value = var.enable_grafana_persistence ? "true" : "false"
  }

  set {
    name  = "grafana.persistence.storageClassName"
    value = var.enable_ebs_storage_class ? kubernetes_storage_class.prometheus_gp3[0].metadata[0].name : "gp3"
  }

  set {
    name  = "grafana.persistence.size"
    value = var.grafana_storage_size
  }

  # Grafana resource limits
  set {
    name  = "grafana.resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "grafana.resources.limits.memory"
    value = "256Mi"
  }

  set {
    name  = "grafana.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "grafana.resources.requests.memory"
    value = "128Mi"
  }

  # Grafana ingress (disabled by default, managed separately)
  set {
    name  = "grafana.ingress.enabled"
    value = "false"
  }

  # Grafana plugins
  set {
    name  = "grafana.plugins[0]"
    value = "grafana-piechart-panel"
  }

  set {
    name  = "grafana.plugins[1]"
    value = "grafana-clock-panel"
  }

  # Grafana datasources
  set {
    name  = "grafana.datasources.datasources\\.yaml.apiVersion"
    value = "1"
  }

  # ============================================================================
  # Alertmanager Configuration
  # ============================================================================

  # Alertmanager replicas
  set {
    name  = "alertmanager.alertmanagerSpec.replicas"
    value = "1"
  }

  # Alertmanager resource limits
  set {
    name  = "alertmanager.alertmanagerSpec.resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.resources.limits.memory"
    value = "128Mi"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.resources.requests.memory"
    value = "64Mi"
  }

  # ============================================================================
  # Prometheus Operator Configuration
  # ============================================================================

  # Operator resource limits
  set {
    name  = "prometheusOperator.resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "prometheusOperator.resources.limits.memory"
    value = "256Mi"
  }

  set {
    name  = "prometheusOperator.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "prometheusOperator.resources.requests.memory"
    value = "128Mi"
  }

  # ============================================================================
  # Node Exporter Configuration
  # ============================================================================

  # Node exporter resource limits
  set {
    name  = "nodeExporter.resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "nodeExporter.resources.limits.memory"
    value = "50Mi"
  }

  set {
    name  = "nodeExporter.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "nodeExporter.resources.requests.memory"
    value = "30Mi"
  }

  # ============================================================================
  # Kube State Metrics Configuration
  # ============================================================================

  # Kube state metrics resource limits
  set {
    name  = "kube-state-metrics.resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "kube-state-metrics.resources.limits.memory"
    value = "128Mi"
  }

  set {
    name  = "kube-state-metrics.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "kube-state-metrics.resources.requests.memory"
    value = "64Mi"
  }

  depends_on = [
    kubernetes_namespace.monitoring
  ]
}

# ============================================================================
# Grafana Ingress
# ============================================================================

resource "kubernetes_ingress_v1" "grafana" {
  count = var.enable_monitoring && var.enable_alb_controller ? 1 : 0

  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name

    annotations = {
      "kubernetes.io/ingress.class"                    = var.ingress_class
      "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"         = "443"
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/api/health"
      "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
      "cert-manager.io/cluster-issuer"                 = var.enable_cert_manager ? (var.letsencrypt_environment == "production" ? "letsencrypt-production" : "letsencrypt-staging") : ""
    }

    labels = {
      "app.kubernetes.io/name"       = "grafana"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    ingress_class_name = var.ingress_class

    dynamic "tls" {
      for_each = var.enable_cert_manager ? [1] : []
      content {
        hosts = [
          "grafana.${var.domain_name}"
        ]
        secret_name = "grafana-tls"
      }
    }

    rule {
      host = "grafana.${var.domain_name}"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "kube-prometheus-stack-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}

# ============================================================================
# Prometheus Ingress
# ============================================================================

resource "kubernetes_ingress_v1" "prometheus" {
  count = var.enable_monitoring && var.enable_alb_controller ? 1 : 0

  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name

    annotations = {
      "kubernetes.io/ingress.class"                    = var.ingress_class
      "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"         = "443"
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/-/healthy"
      "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
      "cert-manager.io/cluster-issuer"                 = var.enable_cert_manager ? (var.letsencrypt_environment == "production" ? "letsencrypt-production" : "letsencrypt-staging") : ""
    }

    labels = {
      "app.kubernetes.io/name"       = "prometheus"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    ingress_class_name = var.ingress_class

    dynamic "tls" {
      for_each = var.enable_cert_manager ? [1] : []
      content {
        hosts = [
          "prometheus.${var.domain_name}"
        ]
        secret_name = "prometheus-tls"
      }
    }

    rule {
      host = "prometheus.${var.domain_name}"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "kube-prometheus-stack-prometheus"
              port {
                number = 9090
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.kube_prometheus_stack
  ]
}
