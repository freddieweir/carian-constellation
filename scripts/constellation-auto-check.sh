#!/bin/bash
#
# Carian Constellation Auto-Check Script
# Purpose: Detect long-running infrastructure and alert
# Schedule: Run daily via cron (10 PM local time)
#
# Installation:
#   chmod +x scripts/constellation-auto-check.sh
#   crontab -e
#   Add: 0 22 * * * /Users/fweirvm/git/internal/repos/carian-constellation/scripts/constellation-auto-check.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
AWS_PROFILE="${AWS_PROFILE:-constellation-admin-vm}"
AWS_REGION="us-west-2"
MAX_RUNTIME_HOURS=8
ALERT_EMAIL="aws@freddieweir.com"

# Export profile for AWS CLI commands
export AWS_PROFILE

# Log function
log() {
  echo "[$(date -Iseconds)] $*" | tee -a ~/.constellation-auto-check.log
}

# Check for running EKS cluster
check_cluster() {
  local clusters
  clusters=$(aws eks list-clusters --region "$AWS_REGION" --query 'clusters' --output json 2>/dev/null || echo "[]")

  if [ "$clusters" != "[]" ]; then
    local cluster_name
    cluster_name=$(echo "$clusters" | jq -r '.[0]' 2>/dev/null)

    if [ -n "$cluster_name" ] && [ "$cluster_name" != "null" ]; then
      log "WARNING: EKS cluster detected: $cluster_name"

      # Get cluster age
      local created_at runtime_hours
      created_at=$(aws eks describe-cluster --name "$cluster_name" --region "$AWS_REGION" \
        --query 'cluster.createdAt' --output text 2>/dev/null)

      if [ -n "$created_at" ]; then
        local created_epoch now_epoch

        # Cross-platform date parsing
        if [[ "$OSTYPE" == "darwin"* ]]; then
          # macOS
          created_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${created_at%.*}" "+%s" 2>/dev/null || echo "0")
        else
          # Linux
          created_epoch=$(date -d "$created_at" +%s 2>/dev/null || echo "0")
        fi

        now_epoch=$(date +%s)
        runtime_hours=$(( (now_epoch - created_epoch) / 3600 ))

        log "Cluster runtime: ${runtime_hours} hours"

        # Alert if over threshold
        if [ "$runtime_hours" -gt "$MAX_RUNTIME_HOURS" ]; then
          send_alert "$cluster_name" "$runtime_hours"
        fi
      fi

      return 1  # Cluster found
    fi
  fi

  log "INFO: No clusters running"
  return 0  # No cluster
}

# Send alert email
send_alert() {
  local cluster_name=$1
  local runtime_hours=$2
  local estimated_cost
  estimated_cost=$(echo "scale=2; $runtime_hours * 0.25" | bc)

  local subject="🚨 Constellation Alert: Long-Running Infrastructure"
  local body="WARNING: EKS cluster '$cluster_name' has been running for $runtime_hours hours

Estimated cost: \$$estimated_cost

This exceeds the $MAX_RUNTIME_HOURS hour threshold.

Action Required:
1. Verify if infrastructure is still needed
2. If not needed, run:
   cd $PROJECT_ROOT
   ./scripts/constellation-down.sh

3. Verify destruction:
   aws eks list-clusters --region $AWS_REGION --profile $AWS_PROFILE

Region: $AWS_REGION
Detected: $(date)
"

  # Try to send email (requires mailx or similar)
  if command -v mail >/dev/null 2>&1; then
    echo "$body" | mail -s "$subject" "$ALERT_EMAIL"
    log "Alert email sent to $ALERT_EMAIL"
  else
    log "ERROR: Cannot send email - 'mail' command not found"
    log "Alert details: $subject - $runtime_hours hours, \$$estimated_cost"

    # Try to write to notification file instead
    local notif_file="$HOME/.constellation-alert.txt"
    echo "$subject" > "$notif_file"
    echo "" >> "$notif_file"
    echo "$body" >> "$notif_file"
    log "Alert written to: $notif_file"
  fi
}

# Check running EC2 instances
check_instances() {
  local instances
  instances=$(aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "Name=instance-state-name,Values=running" \
              "Name=tag:Project,Values=CarianConstellation" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text 2>/dev/null || echo "")

  if [ -n "$instances" ]; then
    log "WARNING: Running EC2 instances detected: $instances"
    return 1
  fi

  return 0
}

# Check NAT gateways
check_nat_gateways() {
  local nat_gateways
  nat_gateways=$(aws ec2 describe-nat-gateways --region "$AWS_REGION" \
    --filter "Name=state,Values=available" \
             "Name=tag:Project,Values=CarianConstellation" \
    --query 'NatGateways[*].NatGatewayId' --output text 2>/dev/null || echo "")

  if [ -n "$nat_gateways" ]; then
    log "WARNING: Active NAT gateways detected: $nat_gateways"
    return 1
  fi

  return 0
}

# Main execution
main() {
  log "=== Starting Constellation Auto-Check ==="

  local issues=0

  check_cluster || ((issues++))
  check_instances || ((issues++))
  check_nat_gateways || ((issues++))

  if [ $issues -eq 0 ]; then
    log "✅ All clear - no running infrastructure detected"
  else
    log "⚠️  Found $issues potential cost issues"
  fi

  log "=== Auto-Check Complete ==="
}

main "$@"
