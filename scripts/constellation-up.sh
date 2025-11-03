#!/bin/bash
#
# Carian Constellation - Infrastructure Deployment Script
# Purpose: Deploy ephemeral EKS cluster and associated resources
# Lifecycle: Destroys when not in use to minimize costs
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

# Verify AWS credentials
verify_credentials() {
  log "Verifying AWS credentials..."
  if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &>/dev/null; then
    error "AWS credentials not valid. Please configure: $AWS_PROFILE"
    exit 1
  fi
  log "✅ AWS credentials verified"
}

# Check if infrastructure already exists
check_existing_infrastructure() {
  log "Checking for existing infrastructure..."

  local clusters
  clusters=$(aws eks list-clusters --region "$AWS_REGION" --query 'clusters' --output json 2>/dev/null || echo "[]")

  if echo "$clusters" | grep -q "$CLUSTER_NAME"; then
    warn "EKS cluster '$CLUSTER_NAME' already exists!"
    read -p "Continue anyway? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      log "Deployment cancelled"
      exit 0
    fi
  fi
}

# Deploy bootstrap infrastructure (if needed)
deploy_bootstrap() {
  log "Checking bootstrap infrastructure..."

  cd "$PROJECT_ROOT/blueprints/terraform/bootstrap"

  if [ ! -f terraform.tfstate ]; then
    warn "Bootstrap infrastructure not found. This should be a one-time setup."
    read -p "Deploy bootstrap infrastructure? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      log "Initializing bootstrap Terraform..."
      terraform init

      log "Deploying bootstrap infrastructure..."
      terraform apply -auto-approve

      log "✅ Bootstrap infrastructure deployed"
    else
      error "Bootstrap infrastructure required. Cannot proceed."
      exit 1
    fi
  else
    log "✅ Bootstrap infrastructure exists"
  fi
}

# Deploy ephemeral infrastructure
deploy_ephemeral() {
  log "Deploying ephemeral infrastructure (EKS cluster, VPC, nodes)..."

  cd "$PROJECT_ROOT/blueprints/terraform/ephemeral"

  # Check if backend.hcl exists
  if [ ! -f backend.hcl ]; then
    error "backend.hcl not found. Cannot initialize Terraform."
    exit 1
  fi

  log "Initializing ephemeral Terraform..."
  terraform init -backend-config=backend.hcl

  log "Planning ephemeral infrastructure..."
  terraform plan -out=tfplan

  log "Applying ephemeral infrastructure..."
  terraform apply tfplan

  log "✅ Ephemeral infrastructure deployed"
}

# Deploy persistent Kubernetes controllers
deploy_persistent() {
  log "Deploying persistent Kubernetes controllers..."

  cd "$PROJECT_ROOT/blueprints/terraform/persistent"

  # Update kubeconfig
  log "Updating kubeconfig..."
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

  log "Initializing persistent Terraform..."
  terraform init -backend-config=backend.hcl

  log "Planning persistent controllers..."
  terraform plan -out=tfplan

  log "Applying persistent controllers..."
  terraform apply tfplan

  log "✅ Persistent controllers deployed"
}

# Deploy Kubernetes applications
deploy_applications() {
  log "Deploying Kubernetes applications..."

  cd "$PROJECT_ROOT/blueprints/kubernetes"

  log "Deploying namespaces..."
  kubectl apply -f namespaces/

  log "Deploying secrets..."
  kubectl apply -f secrets/

  log "Deploying applications..."
  kubectl apply -f applications/

  log "Deploying ingress..."
  kubectl apply -f ingress/

  log "Deploying monitoring..."
  kubectl apply -f monitoring/

  log "✅ Applications deployed"
}

# Wait for pods to be ready
wait_for_pods() {
  log "Waiting for pods to be ready..."

  kubectl wait --for=condition=ready pod --all --all-namespaces --timeout=300s || {
    warn "Some pods may not be ready yet. Check with: kubectl get pods -A"
  }

  log "✅ Pods are ready"
}

# Main deployment flow
main() {
  log "╔════════════════════════════════════════════════════════════════╗"
  log "║       Carian Constellation - Infrastructure Deployment        ║"
  log "╚════════════════════════════════════════════════════════════════╝"
  log ""

  verify_credentials
  check_existing_infrastructure
  deploy_bootstrap
  deploy_ephemeral
  deploy_persistent
  deploy_applications
  wait_for_pods

  log ""
  log "╔════════════════════════════════════════════════════════════════╗"
  log "║                   🎉 Deployment Complete! 🎉                   ║"
  log "╚════════════════════════════════════════════════════════════════╝"
  log ""

  # Show cost warning and reminder
  cat << 'EOF'

╔════════════════════════════════════════════════════════════════╗
║                   ⚠️  CRITICAL REMINDER ⚠️                      ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  Infrastructure is NOW RUNNING and costing money!              ║
║                                                                ║
║  Hourly Cost:  $0.25/hour                                      ║
║  Daily Cost:   $6.00/day                                       ║
║  Max Runtime:  4 hours recommended                             ║
║                                                                ║
║  ACTION REQUIRED:                                              ║
║  1. Set a timer NOW for your estimated usage duration          ║
║  2. Run ./scripts/constellation-down.sh when finished          ║
║  3. Verify destruction:                                        ║
║     aws eks list-clusters --region us-west-2 \                 ║
║       --profile constellation-admin-vm                         ║
║                                                                ║
║  Expected after teardown: {"clusters": []}                     ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

EOF

  # Log the startup
  echo "$(date -Iseconds) | UP | region=$AWS_REGION | cluster=$CLUSTER_NAME" >> \
    ~/.constellation-usage.log

  # Interactive prompt (forces acknowledgment)
  echo ""
  read -p "Press Enter to acknowledge you will tear down infrastructure when done..."
  echo ""
  log "✅ Acknowledged. Happy testing!"
  log ""
  log "Access your services:"
  log "  kubectl get pods -A"
  log "  kubectl get ingress -A"
  log ""
}

main "$@"
