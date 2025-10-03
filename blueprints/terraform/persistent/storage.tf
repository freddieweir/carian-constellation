# ============================================================================
# Storage Configuration
# ============================================================================

# ============================================================================
# EBS Storage Classes
# ============================================================================

# General purpose gp3 storage (default)
resource "kubernetes_storage_class" "gp3" {
  count = var.enable_ebs_storage_class ? 1 : 0

  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }
}

# High performance storage with higher IOPS
resource "kubernetes_storage_class" "gp3_high_iops" {
  count = var.enable_ebs_storage_class ? 1 : 0

  metadata {
    name = "gp3-high-iops"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type       = "gp3"
    iops       = "10000"
    throughput = "250"
    encrypted  = "true"
    fsType     = "ext4"
  }
}

# Database workload storage (io2)
resource "kubernetes_storage_class" "io2_database" {
  count = var.enable_ebs_storage_class ? 1 : 0

  metadata {
    name = "io2-database"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Retain"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type      = "io2"
    iops      = "10000"
    encrypted = "true"
    fsType    = "ext4"
  }
}

# Retain policy storage for critical data
resource "kubernetes_storage_class" "gp3_retain" {
  count = var.enable_ebs_storage_class ? 1 : 0

  metadata {
    name = "gp3-retain"
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
# EFS Storage Class (Optional - for shared storage)
# ============================================================================

# EFS CSI Driver
resource "helm_release" "efs_csi_driver" {
  count = var.enable_efs_storage_class && var.efs_file_system_id != "" ? 1 : 0

  name       = "aws-efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  version    = "2.5.1"
  namespace  = "kube-system"

  set {
    name  = "controller.serviceAccount.create"
    value = "true"
  }

  # Resource limits for controller
  set {
    name  = "controller.resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "128Mi"
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "64Mi"
  }

  # Resource limits for node daemonset
  set {
    name  = "node.resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "node.resources.limits.memory"
    value = "128Mi"
  }

  set {
    name  = "node.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "node.resources.requests.memory"
    value = "64Mi"
  }
}

# EFS Storage Class
resource "kubernetes_storage_class" "efs" {
  count = var.enable_efs_storage_class && var.efs_file_system_id != "" ? 1 : 0

  metadata {
    name = "efs"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Retain"
  volume_binding_mode = "Immediate"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = var.efs_file_system_id
    directoryPerms   = "700"
  }

  depends_on = [
    helm_release.efs_csi_driver
  ]
}

# ============================================================================
# Volume Snapshot Classes
# ============================================================================

resource "kubernetes_manifest" "volume_snapshot_class_ebs" {
  count = var.enable_ebs_storage_class ? 1 : 0

  manifest = {
    apiVersion = "snapshot.storage.k8s.io/v1"
    kind       = "VolumeSnapshotClass"
    metadata = {
      name = "ebs-csi-snapclass"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    driver         = "ebs.csi.aws.com"
    deletionPolicy = "Delete"
    parameters = {
      encrypted = "true"
    }
  }
}
