#!/bin/bash
#
# Carian Constellation - Infrastructure Teardown Script
# Purpose: Destroy ephemeral infrastructure to stop costs
# Safety: Backs up data before destruction
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
AWS_PROFILE="${AWS_PROFILE:-constellation-admin-vm}"
AWS_REGION="${AWS_REGION:-us-west-2}"
CLUSTER_NAME="${CLUSTER_NAME:-constellation-dev}"

# Export for AWS CLI commands
export AWS_PROFILE
export AWS_REGION

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
  echo -e "${GREEN}[$(date -Iseconds)]${NC} $*"
}

error() {
  echo -e "${RED}[$(date -Iseconds)] ERROR:${NC} $*" >&2
}

warn() {
  echo -e "${YELLOW}[$(date -Iseconds)] WARNING:${NC} $*"
}

# Calculate runtime and cost
calculate_usage() {
  if [ -f ~/.constellation-usage.log ]; then
    LAST_UP=$(grep "UP" ~/.constellation-usage.log | tail -1)
    if [ -n "$LAST_UP" ]; then
      START_TIME=$(echo "$LAST_UP" | cut -d'|' -f1 | xargs)

      # Parse ISO 8601 timestamp (cross-platform)
      if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${START_TIME%+*}" "+%s" 2>/dev/null || echo "0")
      else
        # Linux
        START_EPOCH=$(date -d "$START_TIME" +%s 2>/dev/null || echo "0")
      fi

      END_EPOCH=$(date +%s)
      RUNTIME_SECONDS=$((END_EPOCH - START_EPOCH))
      RUNTIME_HOURS=$(echo "scale=2; $RUNTIME_SECONDS / 3600" | bc)
      ESTIMATED_COST=$(echo "scale=2; $RUNTIME_HOURS * 0.25" | bc)

      echo ""
      echo "╔════════════════════════════════════════════════════════════════╗"
      echo "║                     Usage Summary                              ║"
      echo "╠════════════════════════════════════════════════════════════════╣"
      printf "║  Runtime:        %-40s ║\n" "${RUNTIME_HOURS} hours"
      printf "║  Estimated Cost: %-40s ║\n" "\$$ESTIMATED_COST"
      echo "╚════════════════════════════════════════════════════════════════╝"
      echo ""

      # Log the shutdown
      echo "$(date -Iseconds) | DOWN | runtime=${RUNTIME_HOURS}h | cost=\$${ESTIMATED_COST}" >> \
        ~/.constellation-usage.log
    else
      warn "No matching UP entry found in usage log"
    fi
  else
    warn "Usage log not found at ~/.constellation-usage.log"
  fi
}

# Verify AWS credentials
verify_credentials() {
  log "Verifying AWS credentials..."
  if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &>/dev/null; then
    error "AWS credentials not valid. Please configure: $AWS_PROFILE"
    exit 1
  fi
  log "✅ AWS credentials verified"
}

# Backup data before destruction
backup_data() {
  log "Backing up data..."

  # Check if cluster exists first
  if ! aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" &>/dev/null; then
    log "ℹ️  No cluster found - skipping backup"
    return 0
  fi

  # Update kubeconfig
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" || {
    warn "Could not update kubeconfig - cluster may not be accessible"
    return 0
  }

  # Create backup directory
  BACKUP_DIR="$PROJECT_ROOT/backups/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_DIR"

  # Backup PostgreSQL (if accessible)
  if kubectl get namespace carian-data &>/dev/null; then
    log "Backing up PostgreSQL database..."
    kubectl exec -n carian-data postgresql-0 -c postgresql -- \
      pg_dump -U carianuser cariandb > "$BACKUP_DIR/cariandb-backup.sql" 2>/dev/null || {
      warn "PostgreSQL backup failed - pod may not be ready"
    }
  fi

  # Backup Kubernetes manifests state
  log "Backing up Kubernetes resources..."
  kubectl get all --all-namespaces -o yaml > "$BACKUP_DIR/all-resources.yaml" 2>/dev/null || true

  log "✅ Backup complete: $BACKUP_DIR"
}

# Clean up Kubernetes resources
cleanup_kubernetes() {
  log "Cleaning up Kubernetes resources..."

  # Check if cluster exists and is accessible
  if ! kubectl cluster-info &>/dev/null; then
    log "ℹ️  Cluster not accessible - skipping Kubernetes cleanup"
    return 0
  fi

  cd "$PROJECT_ROOT/blueprints/kubernetes"

  log "Deleting applications..."
  kubectl delete -f applications/ --ignore-not-found=true --timeout=60s || {
    warn "Some applications may not have been deleted cleanly"
  }

  log "Deleting ingress..."
  kubectl delete -f ingress/ --ignore-not-found=true --timeout=60s || true

  log "Deleting monitoring..."
  kubectl delete -f monitoring/ --ignore-not-found=true --timeout=60s || true

  log "✅ Kubernetes cleanup complete"
}

# Destroy persistent controllers
destroy_persistent() {
  log "Destroying persistent Kubernetes controllers..."

  cd "$PROJECT_ROOT/blueprints/terraform/persistent"

  if [ ! -d .terraform ]; then
    log "ℹ️  Persistent infrastructure not initialized - skipping"
    return 0
  fi

  log "Destroying persistent controllers..."
  terraform destroy -auto-approve || {
    warn "Some persistent resources may not have been destroyed"
    warn "Check AWS console for remaining resources"
  }

  log "✅ Persistent controllers destroyed"
}

# Destroy ephemeral infrastructure
destroy_ephemeral() {
  log "Destroying ephemeral infrastructure..."

  cd "$PROJECT_ROOT/blueprints/terraform/ephemeral"

  if [ ! -d .terraform ]; then
    error "Ephemeral infrastructure not initialized"
    error "Cannot destroy. Check if infrastructure exists in AWS console."
    exit 1
  fi

  log "Planning destruction..."
  terraform plan -destroy -out=tfplan-destroy

  log "Destroying ephemeral infrastructure (this may take 10-15 minutes)..."
  terraform apply tfplan-destroy

  log "✅ Ephemeral infrastructure destroyed"
}

# Verify complete destruction
verify_destruction() {
  log "Verifying complete destruction..."

  local issues=0

  # Check EKS clusters
  local clusters
  clusters=$(aws eks list-clusters --region "$AWS_REGION" --query 'clusters' --output json 2>/dev/null || echo "[]")
  if echo "$clusters" | grep -q "$CLUSTER_NAME"; then
    error "❌ EKS cluster still exists: $CLUSTER_NAME"
    ((issues++))
  else
    log "✅ No EKS clusters found"
  fi

  # Check EC2 instances
  local instances
  instances=$(aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "Name=instance-state-name,Values=running,stopped" \
              "Name=tag:Project,Values=CarianConstellation" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text 2>/dev/null || echo "")

  if [ -n "$instances" ]; then
    error "❌ EC2 instances still running: $instances"
    ((issues++))
  else
    log "✅ No EC2 instances found"
  fi

  # Check NAT gateways
  local nat_gateways
  nat_gateways=$(aws ec2 describe-nat-gateways --region "$AWS_REGION" \
    --filter "Name=state,Values=available" \
             "Name=tag:Project,Values=CarianConstellation" \
    --query 'NatGateways[*].NatGatewayId' --output text 2>/dev/null || echo "")

  if [ -n "$nat_gateways" ]; then
    error "❌ NAT gateways still active: $nat_gateways"
    ((issues++))
  else
    log "✅ No NAT gateways found"
  fi

  # Check Load Balancers
  local load_balancers
  load_balancers=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" \
    --query 'LoadBalancers[?contains(LoadBalancerName, `constellation`) == `true`].LoadBalancerArn' \
    --output text 2>/dev/null || echo "")

  if [ -n "$load_balancers" ]; then
    warn "⚠️  Load balancers may still exist (check manually)"
  else
    log "✅ No load balancers found"
  fi

  if [ $issues -gt 0 ]; then
    error "❌ Found $issues issues during verification"
    error "Please check AWS console and manually delete remaining resources"
    return 1
  fi

  log "✅ Verification complete - all resources destroyed"
  return 0
}

# Main teardown flow
main() {
  log "╔════════════════════════════════════════════════════════════════╗"
  log "║        Carian Constellation - Infrastructure Teardown          ║"
  log "╚════════════════════════════════════════════════════════════════╝"
  log ""

  # Calculate and display usage first
  calculate_usage

  # Confirm destruction
  warn "This will destroy all ephemeral infrastructure."
  warn "Data will be backed up to $PROJECT_ROOT/backups/"
  echo ""
  read -p "Continue with destruction? (yes/NO): " confirm
  if [[ "$confirm" != "yes" ]]; then
    log "Teardown cancelled"
    exit 0
  fi
  echo ""

  verify_credentials
  backup_data
  cleanup_kubernetes
  destroy_persistent
  destroy_ephemeral
  verify_destruction

  log ""
  log "╔════════════════════════════════════════════════════════════════╗"
  log "║                 🎉 Teardown Complete! 🎉                       ║"
  log "╠════════════════════════════════════════════════════════════════╣"
  log "║  Infrastructure has been destroyed.                            ║"
  log "║  Costs should stop accruing within minutes.                    ║"
  log "║                                                                ║"
  log "║  View usage report:                                            ║"
  log "║    ./scripts/constellation-usage-report.sh                     ║"
  log "╚════════════════════════════════════════════════════════════════╝"
  log ""
}

main "$@"
