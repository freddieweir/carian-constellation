# 🚀 Carian Constellation - Deployment Guide

**Complete step-by-step guide to deploying your secure, cost-optimized Kubernetes constellation**

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup (One-Time)](#initial-setup-one-time)
3. [First Deployment](#first-deployment)
4. [Daily Operations](#daily-operations)
5. [Verification & Testing](#verification--testing)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

Install these before starting:

```bash
# Homebrew (if on macOS)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# AWS CLI
brew install awscli

# Terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# kubectl
brew install kubectl

# aws-vault (for MFA credentials)
brew install aws-vault

# Tailscale
# Download from: https://tailscale.com/download/mac
```

### AWS Account Setup

1. **Create AWS Account** (if you don't have one)
   - Visit: https://aws.amazon.com/
   - Set up billing alerts!

2. **Create IAM User**
   ```
   Username: constellation-admin
   Policies: AdministratorAccess
   ```

3. **Enable MFA** on the IAM user
   - Use your phone or authenticator app
   - Save backup codes!

4. **Create Access Keys**
   - Generate access key ID and secret
   - Save them securely (you'll need them once)

### Required Hardware/Accounts

- ✅ **YubiKey**: For WebAuthn authentication (you already have this!)
- ✅ **Domain Name**: Your own domain (e.g., example.com)
- ✅ **Tailscale Account**: Free at https://login.tailscale.com/start

---

## Initial Setup (One-Time)

### Step 1: Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure
# Enter:
#   AWS Access Key ID: [your key]
#   AWS Secret Access Key: [your secret]
#   Default region: us-east-1
#   Default output format: json

# Set up aws-vault for MFA
aws-vault add constellation
# Enter the same access key and secret

# Test MFA
aws-vault exec constellation -- aws sts get-caller-identity
# It will prompt for your MFA code
```

### Step 2: Set Up Tailscale

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale
sudo tailscale up

# Note your Tailscale IP
tailscale ip -4
# Save this! You'll need it (format: 100.x.x.x)
```

### Step 3: Prepare Your Domain

**Option A: Use Route53** (Recommended)
```bash
# If your domain is already in Route53, great!
# If not, transfer it or create a new zone
aws route53 create-hosted-zone \
  --name yourdomain.com \
  --caller-reference $(date +%s)
```

**Option B: Use External DNS**
- You'll need to point your domain's NS records to Route53
- Or use CNAME records for subdomains

### Step 4: Generate Secrets

```bash
# Generate Authelia secrets
openssl rand -hex 32  # Session secret
openssl rand -hex 32  # Storage encryption key

# Generate Grafana password
openssl rand -base64 32

# Save these somewhere secure (1Password, etc.)
```

### Step 5: Bootstrap Infrastructure

```bash
# Navigate to project directory
cd "/Volumes/My Shared Files/macOS Dev Files stalheim/Carian Constellation"

# Bootstrap persistent resources
cd terraform/bootstrap

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
aws_region      = "us-east-1"
domain_name     = "yourdomain.com"
owner_name      = "stalheim"
owner_email     = "your.email@example.com"
github_username = "yourusername"
EOF

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Create persistent resources (S3, Route53, etc.)
aws-vault exec constellation -- terraform apply

# Save outputs
terraform output -json > bootstrap-outputs.json
```

**This creates**:
- S3 bucket for Terraform state
- DynamoDB table for state locking
- S3 bucket for backups
- Route53 hosted zone
- AWS Secrets Manager secrets

### Step 6: Configure Ephemeral Infrastructure

```bash
cd ../ephemeral

# Create backend configuration
cat > backend.hcl <<EOF
bucket         = "$(cd ../bootstrap && terraform output -raw terraform_state_bucket)"
dynamodb_table = "$(cd ../bootstrap && terraform output -raw terraform_lock_table)"
region         = "us-east-1"
encrypt        = true
EOF

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
aws_region         = "us-east-1"
cluster_name       = "constellation"
domain_name        = "yourdomain.com"
owner_name         = "stalheim"
owner_email        = "your.email@example.com"
github_username    = "yourusername"

# Security
enable_tailscale   = true
my_tailscale_ip    = "100.x.x.x"  # Your Tailscale IP from Step 2

# Get this from: https://login.tailscale.com/admin/settings/keys
tailscale_auth_key = "tskey-auth-xxxxx-xxxxx"

# Optional: Use spot instances for extra savings
use_spot_instances = false  # Start with on-demand for reliability
EOF

# Initialize with remote backend
terraform init -backend-config=backend.hcl
```

### Step 7: Store Secrets in AWS Secrets Manager

```bash
# Store Authelia secrets
aws secretsmanager create-secret \
  --name carian-constellation/authelia/session-secret \
  --secret-string "YOUR_SESSION_SECRET_FROM_STEP4"

aws secretsmanager create-secret \
  --name carian-constellation/authelia/storage-encryption-key \
  --secret-string "YOUR_STORAGE_KEY_FROM_STEP4"

# Store Grafana password
aws secretsmanager create-secret \
  --name carian-constellation/grafana/admin-password \
  --secret-string "YOUR_GRAFANA_PASSWORD_FROM_STEP4"

# Store any API keys (OpenAI, Anthropic, etc.)
aws secretsmanager create-secret \
  --name carian-constellation/api-keys/openai \
  --secret-string "sk-your-openai-key"

aws secretsmanager create-secret \
  --name carian-constellation/api-keys/anthropic \
  --secret-string "sk-ant-your-anthropic-key"
```

---

## First Deployment

### Step 1: Deploy the Constellation

```bash
# From project root
cd "/Volumes/My Shared Files/macOS Dev Files stalheim/Carian Constellation"

# Make scripts executable
chmod +x scripts/*.sh
chmod +x scripts/security/*.sh

# Deploy! (This takes 12-18 minutes)
aws-vault exec constellation -- ./scripts/constellation-up.sh
```

**What happens during spin-up:**
1. ✅ Creates VPC with public/private subnets
2. ✅ Deploys Tailscale relay node
3. ✅ Creates EKS cluster (private endpoint)
4. ✅ Launches worker nodes
5. ✅ Configures kubectl access
6. ✅ Installs core controllers (ALB, cert-manager, external-secrets)
7. ✅ Restores data from S3 (if exists)
8. ✅ Deploys all services

### Step 2: First-Time Authelia Setup

```bash
# Wait for services to be ready
kubectl get pods -n auth
kubectl get pods -n constellation-ai

# Get the internal ALB DNS
kubectl get ingress -n constellation-ai

# Add to /etc/hosts (temporary, until DNS propagates)
# Get ALB private IP via:
nslookup $(kubectl get ingress -n constellation-ai -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

# Add to /etc/hosts:
sudo nano /etc/hosts
# Add line: <ALB-INTERNAL-IP> auth.yourdomain.com webui.yourdomain.com
```

### Step 3: Register YubiKey

```bash
# Open browser (make sure you're on Tailscale!)
open https://auth.yourdomain.com

# Create your user account
# Username: stalheim
# Password: (choose a strong password)

# Register YubiKey
# Click "Register Security Key"
# Insert YubiKey and tap when prompted
# Give it a name: "Primary YubiKey"
```

### Step 4: Test Access

```bash
# Try accessing Open-WebUI
open https://webui.yourdomain.com

# You should be redirected to Authelia
# Login with username and password
# Tap YubiKey when prompted
# You're in! 🎉
```

### Step 5: Configure DNS (Permanent)

```bash
# Get Route53 hosted zone nameservers
aws route53 get-hosted-zone --id $(cd terraform/bootstrap && terraform output -raw route53_zone_id)

# Update your domain registrar to use these nameservers
# (This varies by registrar - check their documentation)

# Verify DNS propagation (can take up to 48 hours)
dig auth.yourdomain.com
dig webui.yourdomain.com
```

---

## Daily Operations

### Starting Your Constellation

```bash
cd "/Volumes/My Shared Files/macOS Dev Files stalheim/Carian Constellation"

# Ensure Tailscale is running
tailscale status

# Spin up (12-18 minutes)
aws-vault exec constellation -- ./scripts/constellation-up.sh

# Access your services
open https://webui.yourdomain.com
```

### Stopping Your Constellation

```bash
# Tear down (5-8 minutes)
# This backs up all data to S3 first!
aws-vault exec constellation -- ./scripts/constellation-down.sh

# Verify it's down
./scripts/constellation-status.sh
```

### Checking Status

```bash
# Quick status check
./scripts/constellation-status.sh

# Detailed Kubernetes status
kubectl get pods --all-namespaces

# Check costs
./scripts/cost-tracker.sh
```

### Viewing Logs

```bash
# Authelia logs
kubectl logs -n auth deployment/authelia -f

# Open-WebUI logs
kubectl logs -n constellation-ai deployment/open-webui -f

# All pods in namespace
kubectl logs -n constellation-ai --all-containers=true --prefix=true -f
```

### Accessing Grafana

```bash
# Get Grafana admin password (if you forgot)
kubectl get secret -n constellation-monitoring grafana-admin-password -o jsonpath='{.data.password}' | base64 -d

# Open Grafana
open https://monitoring.yourdomain.com
```

---

## Verification & Testing

### Verify Tailscale Connectivity

```bash
# Check Tailscale status
tailscale status

# Test connectivity to VPC
ping $(terraform -chdir=terraform/ephemeral output -raw vpc_cidr_block | cut -d'/' -f1)

# Verify you can reach EKS API
kubectl get nodes
```

### Verify Security Layers

```bash
# 1. Test that public access is blocked
# From a different network (not on Tailscale):
curl -I https://webui.yourdomain.com
# Should timeout or return connection refused

# 2. Test YubiKey requirement
# Try accessing service without YubiKey
# Should be blocked at Authelia

# 3. Test AWS MFA
aws sts get-caller-identity
# Should fail without MFA session

aws-vault exec constellation -- aws sts get-caller-identity
# Should work (prompts for MFA)
```

### Verify Backups

```bash
# List backups in S3
aws s3 ls s3://$(cd terraform/bootstrap && terraform output -raw backup_bucket)/backups/

# Test restore process
./scripts/restore-data.sh
```

### Performance Testing

```bash
# Test Open-WebUI response time
time curl -k https://webui.yourdomain.com

# Check pod resource usage
kubectl top nodes
kubectl top pods -n constellation-ai

# View metrics in Grafana
open https://monitoring.yourdomain.com
```

---

## Troubleshooting

### Common Issues

#### Issue: Terraform Apply Fails

```bash
# Check AWS credentials
aws-vault exec constellation -- aws sts get-caller-identity

# Check Terraform state lock
aws dynamodb get-item \
  --table-name $(cd terraform/bootstrap && terraform output -raw terraform_lock_table) \
  --key '{"LockID":{"S":"carian-constellation/ephemeral/terraform.tfstate"}}'

# If locked, force unlock (use carefully!)
terraform force-unlock <LOCK_ID>
```

#### Issue: Can't Access Services

```bash
# 1. Verify Tailscale is connected
tailscale status

# 2. Check if pods are running
kubectl get pods --all-namespaces

# 3. Check ingress
kubectl get ingress -n constellation-ai

# 4. Check Authelia logs
kubectl logs -n auth deployment/authelia --tail=50

# 5. Test internal connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- /bin/bash
# Inside pod: curl http://authelia.auth.svc.cluster.local:9091/api/health
```

#### Issue: YubiKey Not Working

```bash
# 1. Check browser compatibility
# Use Chrome/Brave/Edge (best WebAuthn support)

# 2. Check Authelia configuration
kubectl get configmap -n auth authelia-config -o yaml

# 3. Check Authelia logs for WebAuthn errors
kubectl logs -n auth deployment/authelia | grep -i webauthn

# 4. Re-register YubiKey
# Go to https://auth.yourdomain.com
# Settings > Security > Register New Device
```

#### Issue: High Costs

```bash
# Check running resources
aws ec2 describe-instances --filters "Name=tag:Project,Values=CarianConstellation" "Name=instance-state-name,Values=running"

# Check for undeleted resources
terraform -chdir=terraform/ephemeral state list

# Force cleanup
aws-vault exec constellation -- terraform -chdir=terraform/ephemeral destroy -auto-approve

# Verify nothing is left
aws ec2 describe-instances --filters "Name=tag:Project,Values=CarianConstellation"
```

#### Issue: DNS Not Resolving

```bash
# Check Route53 hosted zone
aws route53 list-hosted-zones

# Check DNS records
aws route53 list-resource-record-sets \
  --hosted-zone-id $(cd terraform/bootstrap && terraform output -raw route53_zone_id)

# Test DNS resolution
dig @8.8.8.8 auth.yourdomain.com
nslookup auth.yourdomain.com

# Flush DNS cache (macOS)
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Getting Help

If you're stuck:

1. Check logs: `kubectl logs -n <namespace> <pod-name>`
2. Review PROJECT_CONTEXT.md for architecture details
3. Check terraform/ephemeral/terraform.tfstate for current state
4. Verify all secrets are in AWS Secrets Manager
5. Test with `kubectl describe pod <pod-name>` for events

---

## Next Steps

Once everything is working:

1. ✅ Set up automated backups (cron job)
2. ✅ Configure alerting in Grafana
3. ✅ Add more services as needed
4. ✅ Optimize costs further (spot instances)
5. ✅ Document your learnings

---

## Important Commands Cheat Sheet

```bash
# Spin up
aws-vault exec constellation -- ./scripts/constellation-up.sh

# Tear down
aws-vault exec constellation -- ./scripts/constellation-down.sh

# Status
./scripts/constellation-status.sh

# Costs
./scripts/cost-tracker.sh

# Kubectl context
kubectl config current-context

# Get all resources
kubectl get all -A

# Forward port for debugging
kubectl port-forward -n constellation-ai svc/open-webui 8080:8080

# Execute into pod
kubectl exec -it -n constellation-ai deployment/open-webui -- /bin/bash

# View recent events
kubectl get events -A --sort-by='.lastTimestamp'
```

---

**You're all set! Your Carian Constellation is ready to shine! ✨**

For more details, see:
- [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) - Full technical context
- [docs/](docs/) - Detailed documentation
- [README.md](README.md) - Project overview
