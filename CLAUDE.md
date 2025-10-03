# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Carian Constellation** is an AWS EKS-based AI platform demonstrating enterprise-grade SRE practices with Zero Trust security and cost optimization through ephemeral infrastructure patterns. This project replicates the Docker Compose "Carian Observatory" in production Kubernetes, designed as a portfolio showcase for SRE/DevOps positions.

**Core Value Proposition**: 85% cost reduction ($10-15/month vs $110+/month) through ephemeral infrastructure while maintaining enterprise security standards.

## Architecture Pattern: Ephemeral Infrastructure

The project uses a **three-layer Terraform module architecture** to enable cost-effective on-demand deployment:

### Layer 1: Bootstrap (One-Time Setup)
**Purpose**: Create foundational resources needed for Terraform state and secrets
**Lifecycle**: Permanent (never destroyed)
**Backend**: Local (chicken-egg problem - this creates the S3 backend)
**Cost**: ~$5.50/month

Resources:
- S3 bucket for Terraform remote state
- DynamoDB table for state locking
- Route53 hosted zone
- AWS Secrets Manager secrets (API keys, certificates)
- IAM policies and roles

### Layer 2: Ephemeral (Spin Up/Down)
**Purpose**: Main cluster infrastructure deployed on-demand
**Lifecycle**: Ephemeral (destroyed when not in use)
**Backend**: S3 (configured via `backend.hcl`)
**Cost**: $0.25/hour when running

Resources:
- EKS cluster and control plane
- VPC with public/private subnets
- NAT gateway
- EC2 worker nodes (2x t3.small)
- Tailscale relay node (t3.micro)
- Security groups and KMS keys
- Internal ALB

### Layer 3: Persistent (Kubernetes Controllers)
**Purpose**: Helm charts for cluster controllers
**Lifecycle**: Deployed after ephemeral cluster exists, destroyed before cluster teardown
**Backend**: S3 (configured via `backend.hcl`)
**Cost**: Included in ephemeral cluster cost

Resources:
- AWS Load Balancer Controller (Helm)
- External Secrets Operator (Helm)
- cert-manager (Helm)
- kube-prometheus-stack (Helm)
- EBS CSI driver (Helm)
- IRSA roles and service accounts

**Deployment Order**: Bootstrap → Ephemeral → Persistent → Kubernetes Manifests
**Teardown Order**: Kubernetes Manifests → Persistent → Ephemeral (Bootstrap remains)

**Key Operations**:
- Spin-up time: 12-18 minutes (ephemeral + persistent + apps)
- Tear-down time: 5-8 minutes (clean up apps, destroy persistent, destroy ephemeral)
- Data automatically backed up to S3 before destroy
- Data automatically restored from S3 after create

## Directory Structure

```
blueprints/
├── terraform/
│   ├── bootstrap/          # One-time persistent infrastructure
│   ├── ephemeral/          # On-demand EKS cluster and networking
│   ├── persistent/         # Kubernetes controllers (ALB, ExternalSecrets, etc.)
│   └── modules/            # Reusable Terraform modules
├── kubernetes/
│   ├── namespaces/         # Namespace definitions with quotas and network policies
│   ├── applications/       # Application deployments (Open-WebUI, Perplexica, PostgreSQL)
│   ├── secrets/            # External Secrets configurations
│   ├── ingress/            # ALB Ingress resources
│   └── monitoring/         # ServiceMonitors and Prometheus alerts
└── scripts/
    ├── constellation-up.sh     # Deploy entire infrastructure
    ├── constellation-down.sh   # Destroy infrastructure with backup
    ├── constellation-status.sh # Check current status
    └── security/               # Security setup scripts
```

## Deployment Workflow

### One-Time Bootstrap
```bash
cd blueprints/terraform/bootstrap
terraform init
terraform apply
# Creates S3 state bucket, Route53 zone, Secrets Manager, DynamoDB lock table
```

### Regular Operations
```bash
# Spin up constellation (from project root)
./scripts/constellation-up.sh
# 1. Deploy ephemeral infrastructure (VPC, EKS, nodes, Tailscale)
# 2. Install Kubernetes controllers
# 3. Restore data from S3
# 4. Deploy applications

# Tear down when finished
./scripts/constellation-down.sh
# 1. Backup data to S3
# 2. Clean up Kubernetes resources
# 3. Destroy ephemeral infrastructure
```

### Terraform Commands

**Bootstrap module** (one-time setup):
```bash
cd blueprints/terraform/bootstrap
terraform init  # Uses local backend (chicken-egg problem)
terraform plan
terraform apply
terraform output -json > bootstrap-outputs.json
```

**Ephemeral module** (main cluster):
```bash
cd blueprints/terraform/ephemeral
# Initialize with partial backend configuration
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
terraform destroy  # When done using cluster
```

**Persistent module** (Kubernetes controllers):
```bash
cd blueprints/terraform/persistent
# Deployed after ephemeral cluster exists
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

**Backend Configuration Pattern**:
- Bootstrap uses local backend (creates the S3 bucket)
- Ephemeral and Persistent use S3 backend (configured via `backend.hcl`)
- State files: `bootstrap/terraform.tfstate` (local), `ephemeral/terraform.tfstate` (S3), `persistent/terraform.tfstate` (S3)
- DynamoDB table used for state locking

### Kubernetes Commands

```bash
# Deploy base infrastructure
kubectl apply -f blueprints/kubernetes/namespaces/
kubectl apply -f blueprints/kubernetes/secrets/

# Deploy applications
kubectl apply -f blueprints/kubernetes/applications/postgresql/
kubectl apply -f blueprints/kubernetes/applications/open-webui/
kubectl apply -f blueprints/kubernetes/applications/perplexica/

# Deploy ingress and monitoring
kubectl apply -f blueprints/kubernetes/ingress/
kubectl apply -f blueprints/kubernetes/monitoring/

# Verify deployments
kubectl get pods -A
kubectl get externalsecret -A  # Should show READY=True
kubectl get ingress -A         # Should show ALB address
```

## Security Model: Zero Trust

Four-layer security architecture (user has Zero Trust background):

1. **Network Layer**: Tailscale Zero Trust VPN
   - Private EKS endpoints only (no public access)
   - Subnet routing through dedicated relay node
   - All access requires Tailscale authentication

2. **Infrastructure Layer**: AWS IAM with mandatory MFA
   - All AWS operations require active MFA session
   - Temporary credentials via aws-vault
   - Client certificates for kubectl access

3. **Application Layer**: Authelia with YubiKey WebAuthn
   - Hardware FIDO2/U2F authentication required
   - No password-only access allowed
   - Per-service authorization

4. **Service Layer**: Kubernetes RBAC
   - Certificate-based authentication
   - Least privilege access policies
   - Audit logging enabled

**Critical Security Requirements**:
- Never expose services publicly (always through Tailscale)
- No hardcoded secrets (use Secrets Manager + External Secrets Operator)
- Private EKS endpoints only
- All data encrypted (KMS for at-rest, TLS for in-transit)

## Technology Stack

**Infrastructure**:
- AWS EKS 1.28+ (ephemeral)
- Terraform 1.5+ with modules (AWS ~5.0, Kubernetes ~2.23, Helm ~2.11)
- Tailscale (Zero Trust networking)
- 2x t3.small worker nodes
- 1x t3.micro Tailscale relay
- Single NAT gateway (cost optimization)
- VPC with public/private subnets

**Kubernetes Controllers** (deployed via persistent Terraform module):
- AWS Load Balancer Controller (ALB ingress with IRSA)
- External Secrets Operator (AWS Secrets Manager sync)
- cert-manager (TLS certificate automation)
- kube-prometheus-stack (Prometheus, Grafana, Alertmanager)
- EBS CSI driver (persistent volumes)

**Applications** (deployed via Kubernetes manifests):
- Open-WebUI (AI chat interface) - `carian-apps` namespace
- Perplexica + SearXNG (AI-powered search) - `carian-apps` namespace
- PostgreSQL (database) - `carian-data` namespace
- Authelia (authentication gateway) - `carian-apps` namespace
- Monitoring stack - `carian-monitoring` namespace

**Namespace Architecture**:
- `carian-apps`: Main applications with resource quotas (4 CPU / 8Gi RAM)
- `carian-data`: Data layer (PostgreSQL) with quotas (2 CPU / 4Gi RAM)
- `carian-monitoring`: Observability stack with privileged pod security
- Each namespace has NetworkPolicies and Pod Security Standards

## Cost Optimization Strategy

**Current Costs**:
- Running: $0.25/hour
- Persistent: $5.50/month
- Weekend use (16hrs/month): $9.50/month total
- Regular use (40hrs/month): $15.50/month total
- Always-on (720hrs/month): $110-145/month

**Optimization Techniques**:
- Ephemeral infrastructure (destroy when not in use)
- Right-sized instances (t3.small/micro)
- Single NAT gateway (saves $32.40/month per extra NAT)
- VPC endpoints (avoid NAT costs for AWS services)
- Consider SPOT instances for 60-70% additional savings

## AWS Resource Tagging

All resources use comprehensive tagging for cost tracking and organization:

```hcl
Owner           = "stalheim"
Project         = "CarianConstellation"
Environment     = "personal"
Lifecycle       = "ephemeral"  # or "persistent"
ManagedBy       = "Terraform"
CostCenter      = "personal-projects"
SecurityZone    = "restricted"
BackupPolicy    = "daily-to-s3"
```

## Code Quality and Pre-commit Hooks

**Pre-commit Framework** - Comprehensive validation before commits:

```bash
# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Run manually on all files
pre-commit run --all-files
```

**Automated Checks**:
- **Terraform**: `terraform fmt`, `terraform validate`, `terraform_docs`, `tflint`, `tfsec`
- **Security**: `gitleaks` (secret detection), detect private keys
- **YAML/Kubernetes**: syntax validation, YAML linting
- **Python**: `black` (formatting), `flake8` (linting)
- **Shell**: `shellcheck` for bash scripts

**Custom Hooks**:
- Block `.tfvars` files from being committed (only `.tfvars.example` allowed)
- Detect AWS credentials in code
- Warn about inline Kubernetes Secrets (prefer External Secrets Operator)
- Validate AWS resource tagging (all resources must have required tags)
- Verify ephemeral resources have `Lifecycle=ephemeral` tag

**TFLint Configuration** (`.tflint.hcl`):
- Enforces required tags: `Owner`, `Project`, `Environment`, `ManagedBy`, `Lifecycle`
- AWS-specific rules for instance types, S3 buckets, security groups
- Terraform best practices (documentation, naming conventions, typed variables)

## Configuration Management

**Sensitive Data**:
- All `.tfvars` files are gitignored (except `.tfvars.example`)
- Use `.tfvars.example` as templates
- Store actual values in AWS Secrets Manager
- Never commit credentials, API keys, or domain-specific values
- Pre-commit hooks prevent accidental credential commits

**Environment Variables** (for scripts):
- `AWS_PROFILE`: AWS credential profile (use with aws-vault for MFA)
- `AWS_REGION`: Default us-east-1
- `CLUSTER_NAME`: constellation-dev
- `TAILSCALE_AUTH_KEY`: Generated from Tailscale console (ephemeral, store in Secrets Manager)

## Common Tasks

### Check cluster status
```bash
kubectl get nodes
kubectl get pods -A
kubectl top nodes
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

### Access services locally
```bash
# Open-WebUI
kubectl port-forward -n carian-apps svc/open-webui 8080:80

# Grafana
kubectl port-forward -n carian-monitoring svc/kube-prometheus-stack-grafana 3000:80

# Prometheus
kubectl port-forward -n carian-monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

### View logs
```bash
kubectl logs -n carian-apps -l app=open-webui -f
kubectl logs -n carian-apps -l app=perplexica -f
kubectl logs -n carian-data postgresql-0 -c postgresql -f
```

### Database operations
```bash
# Connect to PostgreSQL
kubectl exec -it -n carian-data postgresql-0 -c postgresql -- psql -U carianuser -d cariandb

# Backup database
kubectl exec -n carian-data postgresql-0 -c postgresql -- \
  pg_dump -U carianuser cariandb > backup.sql

# Restore database
kubectl exec -i -n carian-data postgresql-0 -c postgresql -- \
  psql -U carianuser cariandb < backup.sql
```

### Scale deployments
```bash
kubectl scale deployment -n carian-apps open-webui --replicas=3
kubectl scale deployment -n carian-apps perplexica --replicas=2
```

### Update application
```bash
kubectl rollout restart deployment -n carian-apps open-webui
kubectl rollout status deployment -n carian-apps open-webui
```

## Development Workflow

### Testing Terraform Changes
```bash
# Validate syntax and configuration
terraform fmt -recursive
terraform validate

# Run tflint
tflint --config=.tflint.hcl

# Security scan with tfsec
tfsec blueprints/terraform/ --exclude-downloaded-modules

# Plan before applying
terraform plan -out=tfplan
terraform show tfplan  # Review the plan
terraform apply tfplan
```

### Testing Kubernetes Manifests
```bash
# Validate YAML syntax
kubectl apply --dry-run=client -f blueprints/kubernetes/

# Validate against cluster (without applying)
kubectl apply --dry-run=server -f blueprints/kubernetes/

# Check for deprecated API versions
kubectl-convert -f blueprints/kubernetes/namespaces/namespaces.yaml
```

### Local Development Iteration
```bash
# Format all code
pre-commit run --all-files

# Test specific pre-commit hook
pre-commit run terraform_fmt --all-files
pre-commit run gitleaks --all-files
```

## Troubleshooting

### Terraform State Issues
```bash
# View current state
terraform -chdir=blueprints/terraform/ephemeral show

# List resources in state
terraform -chdir=blueprints/terraform/ephemeral state list

# Refresh state from actual infrastructure
terraform -chdir=blueprints/terraform/ephemeral refresh

# Unlock state if locked (use lock ID from error message)
terraform -chdir=blueprints/terraform/ephemeral force-unlock <lock-id>
```

### Cluster not accessible
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name constellation-dev

# Verify AWS credentials and MFA
aws sts get-caller-identity

# Check cluster status
aws eks describe-cluster --name constellation-dev --region us-east-1

# Verify Tailscale connectivity
tailscale status
ping <eks-private-endpoint>
```

### Secrets not syncing (External Secrets Operator)
```bash
# Check External Secrets Operator
kubectl get externalsecret -A
kubectl describe externalsecret -n carian-apps open-webui-secrets

# Check operator logs
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets -f

# Verify AWS Secrets Manager access (IRSA permissions)
kubectl describe serviceaccount -n external-secrets-system external-secrets

# Manually trigger sync
kubectl annotate externalsecret -n carian-apps open-webui-secrets force-sync="$(date +%s)" --overwrite
```

### Pods not starting
```bash
# Check pod events and status
kubectl describe pod -n carian-apps <pod-name>

# Check resource constraints (namespace quotas)
kubectl top pods -n carian-apps
kubectl describe resourcequota -n carian-apps

# Check previous logs if pod is restarting
kubectl logs -n carian-apps <pod-name> --previous

# Check image pull issues
kubectl get events -n carian-apps --sort-by='.lastTimestamp'
```

### ALB Ingress not working
```bash
# Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f

# Verify ingress resource
kubectl get ingress -A
kubectl describe ingress -n carian-apps <ingress-name>

# Check AWS ALB in console
aws elbv2 describe-load-balancers --region us-east-1

# Verify IRSA for ALB controller
kubectl describe serviceaccount -n kube-system aws-load-balancer-controller
```

### High costs
```bash
# View resource usage
kubectl top nodes
kubectl top pods -A

# Check for resource leaks (pods not running)
kubectl get pods -A | grep -v Running

# Verify ephemeral resources destroyed
terraform -chdir=blueprints/terraform/ephemeral show

# Check AWS resources still running
aws ec2 describe-instances --region us-east-1 --filters "Name=tag:Project,Values=CarianConstellation"
aws eks list-clusters --region us-east-1
```

## Architecture Patterns and Best Practices

### Terraform Module Design
- **Bootstrap module**: Local backend, creates S3/DynamoDB for remote state
- **Ephemeral module**: Main infrastructure (VPC, EKS, nodes), uses S3 backend with partial config
- **Persistent module**: Kubernetes controllers (Helm charts), uses S3 backend, depends on ephemeral cluster
- **Provider configuration**: Kubernetes/Helm providers configured after EKS cluster creation
- **Default tags**: Applied at provider level for all AWS resources

### IRSA (IAM Roles for Service Accounts) Pattern
Critical for AWS service integration without credentials:
- ALB Controller needs EC2/ELB permissions
- External Secrets Operator needs Secrets Manager read access
- EBS CSI driver needs EC2 volume permissions
- Each has dedicated IAM role with trust policy for EKS OIDC provider

### External Secrets Operator Pattern
```yaml
# Define external secret reference to AWS Secrets Manager
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: app-secrets  # Creates this Kubernetes Secret
  data:
    - secretKey: API_KEY
      remoteRef:
        key: constellation/app/api-key  # AWS Secrets Manager path
```

### Resource Tagging Enforcement
All AWS resources MUST have these tags (enforced by tflint and pre-commit):
- `Owner`, `Project`, `Environment`, `ManagedBy`, `Lifecycle`
- Ephemeral resources: `Lifecycle=ephemeral`
- Persistent resources: `Lifecycle=permanent`

## Important Notes

**Checkpoint-based Development**:
- Work in small increments due to conversation timeout risks
- Wait for user confirmation between major steps
- Save outputs and state frequently
- Terraform plan files help preserve work between checkpoints

**User Context**:
- Has Zero Trust security background (familiar with BeyondCorp, hardware MFA)
- Budget-conscious ($10-15/month target, NOT $100+)
- Wants production-grade patterns for SRE/DevOps job interviews
- Values security over convenience (private endpoints, multi-layer auth)
- Appreciates technical depth and detailed explanations

**Portfolio Purpose**:
- Demonstrates IaC expertise (Terraform modules, remote state, partial backend config)
- Shows Kubernetes production patterns (IRSA, External Secrets, ALB ingress, namespaces)
- Highlights security engineering (Zero Trust, hardware MFA, encryption, RBAC)
- Proves cost optimization skills (85% reduction through ephemeral infrastructure)
- Exhibits SRE practices (backup/restore, monitoring, pre-commit hooks, automation)

## Related Documentation

For detailed information, see:
- [blueprints/README.md](blueprints/README.md) - Main project overview
- [blueprints/PROJECT_CONTEXT.md](blueprints/PROJECT_CONTEXT.md) - Full technical context and decisions
- [blueprints/DEPLOYMENT_GUIDE.md](blueprints/DEPLOYMENT_GUIDE.md) - Step-by-step deployment instructions
- [blueprints/terraform/bootstrap/README.md](blueprints/terraform/bootstrap/README.md) - Bootstrap infrastructure setup
- [blueprints/terraform/ephemeral/README.md](blueprints/terraform/ephemeral/README.md) - Ephemeral cluster deployment
- [blueprints/kubernetes/README.md](blueprints/kubernetes/README.md) - Kubernetes manifests and operations
