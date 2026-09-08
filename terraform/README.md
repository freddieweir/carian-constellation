# Terraform Infrastructure

This directory contains all Infrastructure as Code for Carian Constellation.

## Directory Structure

### `bootstrap/` - One-Time Setup
**Lifecycle**: Permanent (never destroyed)
**Backend**: Local (creates the S3 backend for other modules)
**Cost**: ~$6.50/month

Creates foundational resources:
- S3 bucket for Terraform remote state
- DynamoDB table for state locking
- Route53 hosted zone
- AWS Secrets Manager
- IAM policies and roles

**Usage**:
```bash
cd bootstrap
terraform init
terraform plan
terraform apply
terraform output -json > ../bootstrap-outputs.json
```

### `ephemeral/` - Spin Up/Down Infrastructure
**Lifecycle**: Ephemeral (destroyed when not in use)
**Backend**: S3 (configured via `backend.hcl`)
**Cost**: $0.27/hour when running

Main cluster infrastructure:
- EKS cluster with private endpoint
- VPC (public/private subnets)
- NAT gateway (single AZ)
- EC2 worker nodes (2x t3.small)
- Tailscale relay node (t3.micro)
- Security groups and KMS keys
- Internal ALB

**Usage**:
```bash
cd ephemeral
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
# When done
terraform destroy
```

### `persistent/` - Kubernetes Controllers
**Lifecycle**: Deployed after ephemeral cluster exists
**Backend**: S3 (configured via `backend.hcl`)
**Cost**: Included in ephemeral cost

Helm charts for cluster controllers:
- AWS Load Balancer Controller (IRSA)
- External Secrets Operator (IRSA)
- cert-manager (TLS automation)
- kube-prometheus-stack (monitoring)
- EBS CSI driver (IRSA)

**Usage**:
```bash
cd persistent
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
# Before destroying ephemeral cluster
terraform destroy
```

### `modules/` - Reusable Components
Shared Terraform modules:
- `vpc/` - VPC configuration
- `eks/` - EKS cluster configuration
- `irsa/` - IAM Roles for Service Accounts

## Deployment Order

```
1. Bootstrap (one time)
   ↓
2. Ephemeral (when needed)
   ↓
3. Persistent (after ephemeral)
   ↓
4. Kubernetes manifests (../kubernetes/)
```

## Teardown Order

```
1. Kubernetes manifests cleanup
   ↓
2. Persistent destroy
   ↓
3. Ephemeral destroy
   ↓
(Bootstrap remains)
```

## Backend Configuration

All modules except bootstrap use partial backend configuration:

**backend.hcl** (not committed to git):
```hcl
bucket         = "carian-constellation-tfstate-<unique-suffix>"
region         = "us-east-1"
dynamodb_table = "carian-constellation-tfstate-lock"
encrypt        = true
```

Generate from bootstrap outputs:
```bash
cd bootstrap
terraform output -json | jq -r '.backend_config.value' > ../ephemeral/backend.hcl
terraform output -json | jq -r '.backend_config.value' > ../persistent/backend.hcl
```

## Resource Tagging

All resources MUST have these tags (enforced by tflint):
- `Owner` - Your name
- `Project` - "CarianConstellation"
- `Environment` - "personal"
- `ManagedBy` - "Terraform"
- `Lifecycle` - "ephemeral" or "permanent"

## Development Workflow

```bash
# Format all Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate

# Run tflint
tflint --config=../.tflint.hcl

# Security scan
tfsec . --exclude-downloaded-modules

# Plan with output
terraform plan -out=tfplan
terraform show tfplan
```

## Pre-commit Hooks

The repository has pre-commit hooks that run:
- `terraform fmt`
- `terraform validate`
- `terraform_docs`
- `tflint`
- `tfsec`
- Resource tagging validation

Install hooks: `pre-commit install`

## Important Notes

- **Never commit**: `.tfvars`, `backend.hcl`, state files
- **Always use**: `.tfvars.example` as templates
- **State locking**: DynamoDB ensures no concurrent modifications
- **Encryption**: All state files encrypted in S3
- **MFA required**: All AWS operations require active MFA session
