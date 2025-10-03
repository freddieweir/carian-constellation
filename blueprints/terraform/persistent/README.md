# Persistent Infrastructure - Carian Constellation

This Terraform configuration creates **persistent** infrastructure components that should remain running 24/7 across ephemeral cluster lifecycles. These are the operational components that provide core functionality for your Kubernetes applications.

## 📋 What Gets Created

### 🚀 Core Components

1. **AWS Load Balancer Controller**
   - Manages Application Load Balancers via Kubernetes Ingress resources
   - Automatic SSL/TLS termination
   - Target group management
   - Health checks
   - WAFv2 integration ready

2. **External Secrets Operator**
   - Syncs secrets from AWS Secrets Manager or 1Password
   - Automatic secret rotation
   - ClusterSecretStore configured
   - Works with ExternalSecret CRDs

3. **cert-manager**
   - Automatic TLS certificate issuance from Let's Encrypt
   - HTTP-01 and DNS-01 challenge support
   - Certificate renewal automation
   - Multiple ClusterIssuers (staging, production, DNS)

4. **Monitoring Stack** (Prometheus & Grafana)
   - Full Prometheus monitoring with persistent storage
   - Pre-configured Grafana dashboards
   - Alertmanager for alerts
   - Node Exporter for node metrics
   - Kube State Metrics for Kubernetes metrics
   - ServiceMonitor support

### 🛠️ Supporting Components

5. **Metrics Server**
   - Required for Horizontal Pod Autoscaling (HPA)
   - Enables `kubectl top` commands
   - Resource metrics API

6. **Cluster Autoscaler**
   - Automatic node scaling based on pod resource requests
   - Scales down unused nodes
   - Works with EKS managed node groups

7. **Reloader**
   - Auto-restarts pods when ConfigMaps or Secrets change
   - No manual pod restarts needed
   - Watches all namespaces

8. **Storage Classes**
   - gp3 (default, encrypted)
   - gp3-high-iops (10,000 IOPS)
   - io2-database (high performance, retained)
   - gp3-retain (for critical data)
   - efs (optional, shared storage)

---

## 💰 Estimated Costs

| Component | Monthly Cost | Notes |
|-----------|-------------|-------|
| ALB (per instance) | ~$16-25 | Created by Ingress resources |
| EBS Volumes (20 GB) | ~$1.60 | Prometheus + Grafana storage |
| Data Transfer | Variable | ~$10-30/month typical |
| **TOTAL (minimal)** | **~$30-60/month** | Single ALB + storage |
| **TOTAL (full stack)** | **~$50-100/month** | Multiple ALBs + services |

### 💡 Cost Optimization Tips
1. **Reduce Prometheus retention**: Lower `prometheus_retention_days` (default: 15 days)
2. **Smaller storage volumes**: Reduce `prometheus_storage_size` and `grafana_storage_size`
3. **Disable optional components**: Set `enable_node_problem_detector = false`
4. **Use single ALB**: Share one ALB across multiple services with path-based routing

---

## 🚀 Quick Start

### Prerequisites

1. **Ephemeral infrastructure must be deployed first**:
   ```bash
   cd ../ephemeral
   terraform apply
   ```

2. **Verify cluster access**:
   ```bash
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

3. **Required AWS resources**:
   - Route53 hosted zone for your domain (for DNS-01 challenges)
   - S3 bucket for Terraform state (created in foundation)

### 1. Configure Variables

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

**Minimum required configuration:**
```hcl
# terraform.tfvars
project_name            = "carian-constellation"
environment             = "dev"
aws_region              = "us-east-1"
terraform_state_bucket  = "your-terraform-state-bucket"

owner_email     = "your.email@example.com"
github_username = "yourusername"
domain_name     = "yourdomain.com"

# Let's Encrypt
letsencrypt_email       = "your.email@example.com"
letsencrypt_environment = "staging"  # Start with staging!

# Grafana
grafana_admin_password = "STRONG_PASSWORD_HERE"

# Secrets backend
secrets_backend = "aws-secrets-manager"
```

### 2. Initialize Terraform

```bash
# Initialize Terraform (downloads providers and modules)
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan
```

### 3. Deploy Infrastructure

```bash
# Deploy everything
terraform apply

# Or auto-approve (use carefully!)
terraform apply -auto-approve
```

**Deployment time**: ~10-15 minutes

### 4. Verify Deployment

```bash
# Check all pods are running
kubectl get pods --all-namespaces

# Check Helm releases
helm list --all-namespaces

# Verify Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller

# Verify cert-manager
kubectl get pods -n cert-manager

# Verify External Secrets
kubectl get pods -n external-secrets

# Verify monitoring
kubectl get pods -n monitoring

# Check ClusterIssuers
kubectl get clusterissuer

# Check ClusterSecretStore
kubectl get clustersecretstore
```

### 5. Access Grafana

```bash
# Get Grafana URL from outputs
terraform output grafana_url

# Username: admin
# Password: [from terraform.tfvars]
```

---

## 📁 File Structure

```
persistent/
├── main.tf                    # Core Terraform config & data sources
├── variables.tf               # Input variables
├── alb-controller.tf          # AWS Load Balancer Controller
├── external-secrets.tf        # External Secrets Operator
├── cert-manager.tf            # cert-manager for TLS
├── monitoring.tf              # Prometheus & Grafana stack
├── cluster-components.tf      # Metrics Server, Autoscaler, Reloader
├── storage.tf                 # Storage classes
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example configuration
└── README.md                  # This file
```

---

## 🔧 Component Configuration

### AWS Load Balancer Controller

**Purpose**: Creates AWS Application Load Balancers from Kubernetes Ingress resources

**Usage in applications**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
    - host: app.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

---

### External Secrets Operator

**Purpose**: Syncs secrets from external stores into Kubernetes Secrets

**AWS Secrets Manager setup**:
```bash
# Create secret in AWS Secrets Manager
aws secretsmanager create-secret \
  --name carian-constellation/my-app/database-password \
  --secret-string "super-secret-password"
```

**Usage in applications**:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: database-credentials
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: carian-constellation/my-app/database-password
```

---

### cert-manager

**Purpose**: Automatic TLS certificate management

**Usage in Ingress**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  tls:
    - hosts:
        - app.yourdomain.com
      secretName: app-tls
  rules:
    - host: app.yourdomain.com
      http:
        # ... paths ...
```

**Important**: Start with `letsencrypt-staging` to avoid rate limits!

---

### Monitoring Stack

**Components**:
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and management

**Access**:
```bash
# Grafana
open https://grafana.yourdomain.com

# Prometheus
open https://prometheus.yourdomain.com
```

**Custom metrics**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    prometheus.io/path: "/metrics"
```

---

### Storage Classes

**Available classes**:

1. **gp3** (default)
   - General purpose SSD
   - 3,000 IOPS baseline
   - Encrypted
   - Delete on PVC deletion

2. **gp3-high-iops**
   - 10,000 IOPS
   - 250 MB/s throughput
   - For high-performance workloads

3. **io2-database**
   - Provisioned IOPS
   - 10,000 IOPS
   - **Retained** on PVC deletion
   - For critical database workloads

4. **gp3-retain**
   - Same as gp3 but retained
   - For critical data that should survive cluster deletion

5. **efs** (optional)
   - Shared storage across pods
   - ReadWriteMany access mode
   - Requires EFS file system

**Usage**:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3-retain  # Specify storage class
  resources:
    requests:
      storage: 10Gi
```

---

## 🔄 Updating Components

### Update Helm Chart Versions

```bash
# Update variables.tf with new version
vim variables.tf

# Plan changes
terraform plan

# Apply updates
terraform apply
```

### Update Let's Encrypt Environment

```bash
# Switch from staging to production
vim terraform.tfvars
# Change: letsencrypt_environment = "production"

terraform apply

# Delete old certificates
kubectl delete secret -n your-namespace your-app-tls

# cert-manager will automatically issue new certificate
```

---

## 🗑️ Destroying Infrastructure

### Important: Delete Applications First!

```bash
# 1. Delete all application resources
kubectl delete ingress --all --all-namespaces
kubectl delete svc --all --all-namespaces (except kube-system)
kubectl delete pvc --all --all-namespaces

# Wait for ALBs to be deleted (check AWS console)
# This can take 5-10 minutes

# 2. Destroy persistent infrastructure
terraform destroy

# 3. Then destroy ephemeral infrastructure
cd ../ephemeral
terraform destroy
```

**Why this order?**
- Applications create AWS resources (ALBs, Target Groups)
- Terraform doesn't track these resources
- Must be deleted before Terraform destroy
- Otherwise: orphaned AWS resources and failed destroy

---

## 🛠️ Troubleshooting

### ALB Controller Issues

```bash
# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Common issues:
# 1. IAM permissions - check role and policy
# 2. Subnet tags - ensure public subnets have correct tags
# 3. VPC ID mismatch - verify VPC configuration
```

### External Secrets Issues

```bash
# Check operator logs
kubectl logs -n external-secrets deployment/external-secrets

# Verify ClusterSecretStore
kubectl describe clustersecretstore aws-secrets-manager

# Check ExternalSecret status
kubectl describe externalsecret -n your-namespace your-secret

# Common issues:
# 1. IAM permissions - check IRSA role
# 2. Secret path incorrect - verify AWS secret name
# 3. Region mismatch - ensure correct region
```

### cert-manager Issues

```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate status
kubectl describe certificate -n your-namespace your-cert

# Check challenge status
kubectl get challenge --all-namespaces

# Common issues:
# 1. DNS not pointing to ALB
# 2. HTTP-01 challenge path blocked
# 3. Rate limits (use staging first!)
# 4. Route53 permissions for DNS-01
```

### Monitoring Issues

```bash
# Check Prometheus status
kubectl get prometheus -n monitoring

# Check Prometheus logs
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0

# Check Grafana logs
kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana

# Access Grafana locally (if Ingress not working)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
open http://localhost:3000
```

---

## 📚 Additional Resources

- [AWS Load Balancer Controller Docs](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [External Secrets Operator](https://external-secrets.io/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Documentation](https://grafana.com/docs/)

---

## 🔐 Security Best Practices

### ✅ Implemented
- [x] IRSA (IAM Roles for Service Accounts) for all AWS access
- [x] Encrypted EBS volumes for persistent storage
- [x] TLS certificates from Let's Encrypt
- [x] Secrets stored in AWS Secrets Manager (encrypted at rest)
- [x] Private cluster endpoints (via Tailscale)
- [x] Resource limits on all components

### 🎯 Recommended
- [ ] Enable ALB access logging
- [ ] Configure Alertmanager with Slack/PagerDuty
- [ ] Set up Grafana OAuth (GitHub, Google, etc.)
- [ ] Enable Prometheus remote write (long-term storage)
- [ ] Configure WAFv2 rules for ALBs
- [ ] Add network policies for pod-to-pod communication

---

**Created by**: Stalheim  
**Project**: Carian Constellation  
**Last Updated**: October 2025
