# Operational Scripts

This directory contains automation scripts for deploying, managing, and tearing down Carian Constellation.

## Main Scripts

### `constellation-up.sh` 🚀
**Purpose**: Deploy entire infrastructure in one command
**Duration**: 12-18 minutes
**Usage**: `./scripts/constellation-up.sh`

**What it does**:
1. Deploy ephemeral infrastructure (Terraform ephemeral module)
   - Creates VPC, subnets, NAT gateway
   - Deploys EKS cluster with private endpoint
   - Launches worker nodes and Tailscale relay
2. Deploy Kubernetes controllers (Terraform persistent module)
   - Installs ALB Controller, External Secrets, cert-manager, monitoring
3. Restore data from S3 backups
   - Downloads latest database backup
   - Restores PostgreSQL and Open-WebUI data
4. Deploy applications (kubectl apply)
   - Creates namespaces, secrets, deployments, ingress

**Requirements**:
- AWS credentials with MFA
- Tailscale auth key
- Bootstrap infrastructure already deployed

### `constellation-down.sh` 💥
**Purpose**: Destroy infrastructure to save costs
**Duration**: 5-8 minutes
**Usage**: `./scripts/constellation-down.sh`

**What it does**:
1. Backup all data to S3
   - PostgreSQL database dump
   - Open-WebUI data archive
   - Configuration backups
2. Clean up Kubernetes resources
   - Delete application pods and services
   - Remove ingress (triggers ALB cleanup)
   - Delete persistent volumes
3. Destroy Kubernetes controllers (Terraform destroy persistent)
4. Destroy infrastructure (Terraform destroy ephemeral)

**Safety Features**:
- Confirms backup completion before destruction
- Retries if backup fails
- Saves state even if Terraform destroy fails

### `constellation-status.sh` 📊
**Purpose**: Check current infrastructure state
**Usage**: `./scripts/constellation-status.sh`

**What it shows**:
- Terraform state status (ephemeral/persistent modules)
- EKS cluster status
- Node health and resource usage
- Pod status across all namespaces
- External Secrets sync status
- ALB Ingress status
- Estimated hourly cost

### `backup-data.sh` 💾
**Purpose**: Backup all application data to S3
**Usage**: `./scripts/backup-data.sh`

**What it backs up**:
- PostgreSQL database (pg_dump)
- Open-WebUI data volume
- Authelia database
- Configuration files
- Timestamps for restore validation

**Backup location**: `s3://carian-constellation-backups-<suffix>/backups/`

### `restore-data.sh` 📥
**Purpose**: Restore data from S3 backups
**Usage**: `./scripts/restore-data.sh [backup-timestamp]`

**What it restores**:
- Downloads backup from S3
- Restores PostgreSQL database
- Restores Open-WebUI data
- Validates restoration

**Options**:
- No argument: Restores latest backup
- With timestamp: Restores specific backup

## Security Scripts (`security/`)

### `setup-tailscale.sh`
**Purpose**: Configure Tailscale relay node
**Usage**: `./scripts/security/setup-tailscale.sh`

**What it does**:
- Generates Tailscale auth key
- Stores auth key in AWS Secrets Manager
- Updates Terraform variables
- Configures subnet routing

### `generate-kubectl-certs.sh`
**Purpose**: Generate client certificates for kubectl
**Usage**: `./scripts/security/generate-kubectl-certs.sh`

**What it does**:
- Creates client certificate and key
- Adds to kubeconfig
- Configures RBAC for cluster access

### `configure-yubikey.sh`
**Purpose**: Set up YubiKey WebAuthn for Authelia
**Usage**: `./scripts/security/configure-yubikey.sh`

**What it does**:
- Tests YubiKey connectivity
- Generates WebAuthn credentials
- Registers YubiKey with Authelia

## Development Scripts

### `cost-tracker.sh`
**Purpose**: Track actual AWS spending
**Usage**: `./scripts/cost-tracker.sh`

**What it shows**:
- Current month-to-date costs
- Cost by service (EKS, EC2, ALB, etc.)
- Estimated monthly total
- Comparison to budget

### `health-check.sh`
**Purpose**: Comprehensive platform health check
**Usage**: `./scripts/health-check.sh`

**What it checks**:
- AWS resources status
- Kubernetes cluster health
- Pod status and resource usage
- External Secrets sync status
- Ingress and TLS certificates
- Monitoring stack health

## Script Standards

All scripts follow these patterns:

**Error Handling**:
```bash
set -euo pipefail  # Exit on error, undefined variables, pipe failures

# Trap cleanup on exit
cleanup() {
    echo "Cleaning up..."
}
trap cleanup EXIT
```

**Logging**:
```bash
# Consistent log format
log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; }
log_success() { echo "[SUCCESS] $*"; }
```

**AWS MFA Check**:
```bash
# All scripts verify active MFA session
check_aws_mfa() {
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS credentials not configured or MFA expired"
        exit 1
    fi
}
```

**Dry-run Support**:
```bash
# --dry-run flag for testing
if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "DRY RUN: Would execute: $command"
else
    eval "$command"
fi
```

## Usage Examples

### Full deployment workflow
```bash
# Spin up infrastructure
./scripts/constellation-up.sh

# Check status
./scripts/constellation-status.sh

# Use your services (via Tailscale)
# ...

# Tear down when finished
./scripts/constellation-down.sh
```

### Backup before making changes
```bash
# Manual backup
./scripts/backup-data.sh

# Make changes to cluster
# ...

# Restore if needed
./scripts/restore-data.sh
```

### Check costs regularly
```bash
# Weekly cost check
./scripts/cost-tracker.sh

# If over budget, tear down
./scripts/constellation-down.sh
```

## Environment Variables

Scripts use these environment variables:

**Required**:
- `AWS_PROFILE` - AWS credential profile
- `AWS_REGION` - AWS region (default: us-east-1)
- `CLUSTER_NAME` - EKS cluster name (default: constellation-dev)

**Optional**:
- `TAILSCALE_AUTH_KEY` - Tailscale authentication key
- `DRY_RUN` - Set to "true" for dry-run mode
- `BACKUP_RETENTION_DAYS` - S3 backup retention (default: 30)
- `LOG_LEVEL` - Verbosity (DEBUG, INFO, WARN, ERROR)

## Troubleshooting

### constellation-up.sh fails
```bash
# Check Terraform state
cd terraform/ephemeral
terraform state list

# Check AWS resources
aws eks describe-cluster --name constellation-dev --region us-east-1

# View detailed logs
./scripts/constellation-up.sh 2>&1 | tee deploy.log
```

### Backup fails
```bash
# Check S3 bucket access
aws s3 ls s3://carian-constellation-backups-<suffix>/

# Verify pod access to database
kubectl exec -it -n carian-data postgresql-0 -c postgresql -- psql -U carianuser -l

# Manual backup
kubectl exec -n carian-data postgresql-0 -c postgresql -- \
  pg_dump -U carianuser cariandb > manual-backup.sql
```

### Restore fails
```bash
# List available backups
aws s3 ls s3://carian-constellation-backups-<suffix>/backups/

# Download backup manually
aws s3 cp s3://carian-constellation-backups-<suffix>/backups/latest.tar.gz .

# Extract and inspect
tar -xzf latest.tar.gz
```

## Important Notes

- **Always backup** before making infrastructure changes
- **Check costs** weekly with cost-tracker.sh
- **Verify backups** periodically with test restores
- **Use dry-run** for testing script changes
- **Log output** for troubleshooting (use `tee`)
- **MFA required** for all AWS operations
