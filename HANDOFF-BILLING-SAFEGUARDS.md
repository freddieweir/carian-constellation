# Handoff: Implement Billing Safeguards for Carian Constellation

**Created**: November 1, 2025
**Context**: Post-incident prevention measures from INCIDENT-2025-11-01-BILLING.md
**Estimated Time**: 2-3 hours
**Priority**: High (Financial Risk Mitigation)

---

## Background

After a $357.98 billing incident where ephemeral infrastructure ran for 19 days unintentionally, multiple safeguards need to be implemented to prevent recurrence. CloudWatch billing alarm has been configured, but additional operational safeguards are required.

**Related Documents**:
- [INCIDENT-2025-11-01-BILLING.md](INCIDENT-2025-11-01-BILLING.md) - Full incident report
- [CLAUDE.md](CLAUDE.md) - Project documentation

---

## Current State

### What's Already Done ✅
- CloudWatch billing alarm configured ($5 daily threshold)
- SNS topic created: `arn:aws:sns:us-east-1:<aws-account-id>:constellation-billing-alerts`
- All infrastructure destroyed (100 resources removed)
- Incident report documented

### What's Pending ⏳
- SNS email subscription confirmation (check inbox for AWS confirmation)
- Script updates for operational reminders
- Automated monitoring scripts
- Operational checklists
- Usage logging system
- AWS Budget creation

---

## Objectives

Implement multiple layers of protection to prevent unintentional long-running infrastructure:

1. **User Awareness** - Remind operators to tear down infrastructure
2. **Automated Monitoring** - Daily checks for running resources
3. **Cost Tracking** - Log all usage for transparency
4. **Proactive Alerts** - Multiple alert thresholds
5. **Documentation** - Clear operational procedures

---

## Task Breakdown

### Phase 1: User-Facing Safeguards (30 minutes)

#### Task 1.1: Update constellation-up.sh
**File**: `scripts/constellation-up.sh`

**Action**: Add reminder message at script completion (after successful deployment)

**Implementation**:
```bash
# Add after the final "Deployment complete" message, before script exit

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
║  3. Verify destruction: aws eks list-clusters --region us-west-2
║                                                                ║
║  Expected after teardown: {"clusters": []}                     ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

EOF

# Log the startup
echo "$(date -Iseconds) | UP | region=us-west-2 | cluster=constellation-dev" >> \
  ~/.constellation-usage.log

# Interactive prompt (forces acknowledgment)
read -p "Press Enter to acknowledge you will tear down infrastructure when done..."
echo ""
echo "✅ Acknowledged. Happy testing!"
```

**Verification**:
```bash
# Test the updated script
./scripts/constellation-up.sh
# Should show the reminder box and require Enter press
```

---

#### Task 1.2: Update constellation-down.sh
**File**: `scripts/constellation-down.sh`

**Action**: Add usage logging and cost calculation

**Implementation**:
```bash
# Add near the beginning (after any backup operations)

# Calculate runtime and estimated cost
if [ -f ~/.constellation-usage.log ]; then
  LAST_UP=$(grep "UP" ~/.constellation-usage.log | tail -1)
  if [ -n "$LAST_UP" ]; then
    START_TIME=$(echo "$LAST_UP" | cut -d'|' -f1 | xargs)
    START_EPOCH=$(date -d "$START_TIME" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$START_TIME" +%s)
    END_EPOCH=$(date +%s)
    RUNTIME_SECONDS=$((END_EPOCH - START_EPOCH))
    RUNTIME_HOURS=$(echo "scale=2; $RUNTIME_SECONDS / 3600" | bc)
    ESTIMATED_COST=$(echo "scale=2; $RUNTIME_HOURS * 0.25" | bc)

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                     Usage Summary                              ║"
    echo "╠════════════════════════════════════════════════════════════════╣"
    echo "║  Runtime:        ${RUNTIME_HOURS} hours                        "
    echo "║  Estimated Cost: \$${ESTIMATED_COST}                           "
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    # Log the shutdown
    echo "$(date -Iseconds) | DOWN | runtime=${RUNTIME_HOURS}h | cost=\$${ESTIMATED_COST}" >> \
      ~/.constellation-usage.log
  fi
fi

# Continue with terraform destroy...
```

**Verification**:
```bash
# After running constellation-down.sh, check the log
cat ~/.constellation-usage.log
# Should show UP and DOWN entries with runtime/cost
```

---

#### Task 1.3: Create Operational Checklist
**File**: `CONSTELLATION-CHECKLIST.md` (project root)

**Action**: Create new file with pre/post-deployment checklist

**Implementation**:
```bash
cat > $HOME/git/internal/repos/carian-constellation/CONSTELLATION-CHECKLIST.md << 'EOF'
# Carian Constellation Operations Checklist

**Purpose**: Ensure safe, cost-effective operation of ephemeral infrastructure

---

## Pre-Deployment Checklist

Before running `./scripts/constellation-up.sh`:

- [ ] **Verify AWS credentials are active**
  ```bash
  aws sts get-caller-identity --profile constellation-admin-vm
  ```
  Expected: Shows your IAM user ARN

- [ ] **Check current AWS bill is reasonable** (< $20)
  ```bash
  aws ce get-cost-and-usage --profile constellation-admin-vm \
    --time-period Start=$(date -d '1 month ago' +%Y-%m-01),End=$(date +%Y-%m-%d) \
    --granularity MONTHLY --metrics UnblendedCost \
    --region us-east-1 --output table
  ```

- [ ] **Set calendar reminder for 4 hours from now**
  - Title: "Tear down Carian Constellation"
  - Description: "Run: cd ~/git/internal/repos/carian-constellation && ./scripts/constellation-down.sh"

- [ ] **Record planned start time**: ___________

---

## During Operation Checklist

While infrastructure is running:

- [ ] **Set phone/desktop timer for 3 hours** (1-hour warning before limit)

- [ ] **Monitor cluster periodically** (optional, for long sessions)
  ```bash
  # Check cluster status
  aws eks describe-cluster --name constellation-dev --region us-west-2 --profile constellation-admin-vm

  # Check running instances
  aws ec2 describe-instances --region us-west-2 --profile constellation-admin-vm \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].[InstanceId,LaunchTime]'
  ```

- [ ] **Keep usage under 4 hours** for optimal cost control

---

## Post-Operation Checklist (CRITICAL)

When finished with infrastructure:

- [ ] **Run teardown script**
  ```bash
  cd ~/git/internal/repos/carian-constellation
  ./scripts/constellation-down.sh
  ```

- [ ] **Verify complete destruction** (MANDATORY)
  ```bash
  # Check EKS cluster
  aws eks list-clusters --region us-west-2 --profile constellation-admin-vm
  # Expected: {"clusters": []}

  # Check EC2 instances
  aws ec2 describe-instances --region us-west-2 --profile constellation-admin-vm \
    --filters "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[*].Instances[*].InstanceId'
  # Expected: Empty or []

  # Check NAT gateways
  aws ec2 describe-nat-gateways --region us-west-2 --profile constellation-admin-vm \
    --filter "Name=state,Values=available" --query 'NatGateways[*].NatGatewayId'
  # Expected: Empty or []
  ```

- [ ] **Review usage log**
  ```bash
  tail -5 ~/.constellation-usage.log
  # Verify DOWN entry with reasonable runtime/cost
  ```

- [ ] **Cancel calendar reminder** (if infrastructure torn down early)

---

## Emergency Procedures

### If You Forget to Tear Down

1. **Immediate action**: Run constellation-down.sh as soon as you remember
2. **Verify destruction**: Use verification commands above
3. **Check cost impact**:
   ```bash
   aws ce get-cost-and-usage --profile constellation-admin-vm \
     --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
     --granularity DAILY --metrics UnblendedCost \
     --region us-east-1 --group-by Type=DIMENSION,Key=SERVICE
   ```
4. **Document in usage log**: Add manual entry with actual runtime

### If Destruction Fails

1. **Check Terraform state lock**:
   ```bash
   # If locked, force unlock (use lock ID from error message)
   cd blueprints/terraform/ephemeral
   terraform force-unlock -force <LOCK-ID>
   ```

2. **Retry destruction**:
   ```bash
   terraform destroy -var-file=terraform.tfvars -auto-approve
   ```

3. **Manual cleanup if Terraform fails**:
   ```bash
   # Delete EKS cluster
   aws eks delete-cluster --name constellation-dev --region us-west-2

   # Delete node group first if cluster delete fails
   aws eks delete-nodegroup --cluster-name constellation-dev \
     --nodegroup-name <nodegroup-name> --region us-west-2
   ```

---

## Cost Reference

| Runtime | Estimated Cost |
|---------|----------------|
| 1 hour  | $0.25 |
| 2 hours | $0.50 |
| 4 hours | $1.00 |
| 8 hours | $2.00 |
| 1 day   | $6.00 |
| 1 week  | $42.00 |

**Budget Guidelines**:
- ✅ Under 4 hours: Excellent ($1)
- ⚠️ 4-8 hours: Acceptable ($1-2)
- 🚨 Over 8 hours: Review necessity (>$2)
- ❌ Over 24 hours: Incident threshold (>$6)

---

## Monitoring

- **CloudWatch Alarm**: Triggers at $5 daily spend
- **Email**: alerts@example.com (confirm SNS subscription)
- **Usage Log**: ~/.constellation-usage.log

EOF
```

**Verification**:
```bash
cat CONSTELLATION-CHECKLIST.md
# Review the checklist, ensure it's clear and actionable
```

---

### Phase 2: Automated Monitoring (45 minutes)

#### Task 2.1: Create Auto-Check Script
**File**: `scripts/constellation-auto-check.sh`

**Action**: Daily cron job to detect long-running infrastructure

**Implementation**:
```bash
cat > scripts/constellation-auto-check.sh << 'EOF'
#!/bin/bash
#
# Carian Constellation Auto-Check Script
# Purpose: Detect long-running infrastructure and alert
# Schedule: Run daily via cron (10 PM local time)
#
# Installation:
#   chmod +x scripts/constellation-auto-check.sh
#   crontab -e
#   Add: 0 22 * * * $HOME/git/internal/repos/carian-constellation/scripts/constellation-auto-check.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
AWS_PROFILE="${AWS_PROFILE:-constellation-admin-vm}"
AWS_REGION="us-west-2"
MAX_RUNTIME_HOURS=8
ALERT_EMAIL="alerts@example.com"

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
        created_epoch=$(date -d "$created_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${created_at%.*}" +%s)
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
  fi
}

# Check running EC2 instances
check_instances() {
  local instances
  instances=$(aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "Name=instance-state-name,Values=running" \
              "Name=tag:Project,Values=CarianConstellation" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text 2>/dev/null)

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
    --query 'NatGateways[*].NatGatewayId' --output text 2>/dev/null)

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
EOF

chmod +x scripts/constellation-auto-check.sh
```

**Installation**:
```bash
# Test the script manually first
./scripts/constellation-auto-check.sh

# Add to crontab (run daily at 10 PM)
(crontab -l 2>/dev/null; echo "0 22 * * * $HOME/git/internal/repos/carian-constellation/scripts/constellation-auto-check.sh") | crontab -

# Verify crontab entry
crontab -l | grep constellation
```

**Verification**:
```bash
# Check the log after first run
tail -20 ~/.constellation-auto-check.log
```

---

### Phase 3: Cost Tracking & Budgets (30 minutes)

#### Task 3.1: Create AWS Budget
**File**: `scripts/setup-aws-budget.sh`

**Action**: Create monthly budget with progressive alerts

**Implementation**:
```bash
cat > scripts/setup-aws-budget.sh << 'EOF'
#!/bin/bash
#
# Setup AWS Budget for Carian Constellation
# Creates monthly $15 budget with alerts at $10 (66%) and $15 (100%)

set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-constellation-admin-vm}"
AWS_REGION="us-east-1"  # Budgets API only in us-east-1
ACCOUNT_ID="<aws-account-id>"
SNS_TOPIC_ARN="arn:aws:sns:us-east-1:<aws-account-id>:constellation-billing-alerts"

export AWS_PROFILE

# Create budget configuration
cat > /tmp/budget-config.json << 'BUDGET_EOF'
{
  "BudgetName": "constellation-monthly-budget",
  "BudgetLimit": {
    "Amount": "15.00",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostTypes": {
    "IncludeTax": true,
    "IncludeSubscription": true,
    "UseBlended": false,
    "IncludeRefund": false,
    "IncludeCredit": false,
    "IncludeUpfront": true,
    "IncludeRecurring": true,
    "IncludeOtherSubscription": true,
    "IncludeSupport": true,
    "IncludeDiscount": true,
    "UseAmortized": false
  },
  "TimePeriod": {
    "Start": "2025-11-01T00:00:00Z"
  }
}
BUDGET_EOF

# Create notification subscribers
cat > /tmp/budget-notifications.json << NOTIF_EOF
[
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 66.0,
      "ThresholdType": "PERCENTAGE",
      "NotificationState": "ALARM"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "alerts@example.com"
      },
      {
        "SubscriptionType": "SNS",
        "Address": "$SNS_TOPIC_ARN"
      }
    ]
  },
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 100.0,
      "ThresholdType": "PERCENTAGE",
      "NotificationState": "ALARM"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "alerts@example.com"
      },
      {
        "SubscriptionType": "SNS",
        "Address": "$SNS_TOPIC_ARN"
      }
    ]
  },
  {
    "Notification": {
      "NotificationType": "FORECASTED",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 100.0,
      "ThresholdType": "PERCENTAGE",
      "NotificationState": "ALARM"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "alerts@example.com"
      }
    ]
  }
]
NOTIF_EOF

echo "Creating AWS Budget..."

# Create budget
aws budgets create-budget \
  --account-id "$ACCOUNT_ID" \
  --budget file:///tmp/budget-config.json \
  --notifications-with-subscribers file:///tmp/budget-notifications.json \
  --region "$AWS_REGION"

echo "✅ Budget created successfully"
echo ""
echo "Budget Details:"
echo "  Name: constellation-monthly-budget"
echo "  Limit: $15/month"
echo "  Alerts:"
echo "    - 66% ($10): Warning email + SNS"
echo "    - 100% ($15): Critical email + SNS"
echo "    - 100% forecast: Predictive email"
echo ""
echo "Verify at: https://console.aws.amazon.com/billing/home#/budgets"

# Cleanup temp files
rm /tmp/budget-config.json /tmp/budget-notifications.json
EOF

chmod +x scripts/setup-aws-budget.sh
```

**Installation**:
```bash
# Run the budget setup script
./scripts/setup-aws-budget.sh

# Verify budget was created
aws budgets describe-budgets --account-id <aws-account-id> \
  --profile constellation-admin-vm --region us-east-1 \
  --query 'Budgets[?BudgetName==`constellation-monthly-budget`]'
```

---

#### Task 3.2: Create Usage Report Script
**File**: `scripts/constellation-usage-report.sh`

**Action**: Generate usage summary from logs

**Implementation**:
```bash
cat > scripts/constellation-usage-report.sh << 'EOF'
#!/bin/bash
#
# Generate usage report from constellation-usage.log

USAGE_LOG="$HOME/.constellation-usage.log"

if [ ! -f "$USAGE_LOG" ]; then
  echo "No usage log found at $USAGE_LOG"
  exit 1
fi

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Carian Constellation Usage Report                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Count deployments
total_deployments=$(grep -c " UP " "$USAGE_LOG" || echo "0")
echo "Total Deployments: $total_deployments"
echo ""

# Calculate total costs
total_cost=0
while IFS= read -r line; do
  cost=$(echo "$line" | grep -oP 'cost=\$\K[0-9.]+' || echo "0")
  total_cost=$(echo "$total_cost + $cost" | bc)
done < <(grep " DOWN " "$USAGE_LOG")

echo "Total Estimated Cost: \$$total_cost"
echo ""

# Recent activity
echo "Recent Activity (last 10 entries):"
echo "─────────────────────────────────────────────────────────────────"
tail -10 "$USAGE_LOG"
echo ""

# Monthly breakdown
echo "Monthly Breakdown:"
echo "─────────────────────────────────────────────────────────────────"
awk -F'|' '
  /DOWN/ {
    month = substr($1, 1, 7);
    gsub(/cost=\$/, "", $4);
    monthly[month] += $4;
  }
  END {
    for (m in monthly) {
      printf "%s: $%.2f\n", m, monthly[m];
    }
  }
' "$USAGE_LOG" | sort
echo ""

# Check for currently running infrastructure
current_up=$(grep " UP " "$USAGE_LOG" | tail -1)
current_down=$(grep " DOWN " "$USAGE_LOG" | tail -1)

if [ -n "$current_up" ] && [ "$current_up" \> "$current_down" ]; then
  echo "⚠️  WARNING: Infrastructure may still be running!"
  echo "   Last UP:   $current_up"
  echo "   Last DOWN: ${current_down:-Never}"
  echo ""
  echo "   Run: aws eks list-clusters --region us-west-2 --profile constellation-admin-vm"
else
  echo "✅ Infrastructure appears to be torn down"
fi
EOF

chmod +x scripts/constellation-usage-report.sh
```

**Usage**:
```bash
# View usage report anytime
./scripts/constellation-usage-report.sh
```

---

### Phase 4: Testing & Validation (15 minutes)

#### Task 4.1: Test All Safeguards

**Checklist**:
```bash
# 1. Verify CloudWatch alarm exists
aws cloudwatch describe-alarms --alarm-names constellation-daily-cost-alert \
  --region us-east-1 --profile constellation-admin-vm

# 2. Confirm SNS subscription (check email for confirmation link)
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:<aws-account-id>:constellation-billing-alerts \
  --region us-east-1 --profile constellation-admin-vm

# 3. Test auto-check script
./scripts/constellation-auto-check.sh
tail -20 ~/.constellation-auto-check.log

# 4. Test usage report
./scripts/constellation-usage-report.sh

# 5. Verify cron job is scheduled
crontab -l | grep constellation

# 6. Test reminder in constellation-up.sh (if updated)
# Run in test mode or review the code changes

# 7. Verify budget was created
aws budgets describe-budgets --account-id <aws-account-id> \
  --profile constellation-admin-vm --region us-east-1
```

---

## Acceptance Criteria

All tasks are complete when:

- [ ] constellation-up.sh shows prominent reminder message and requires acknowledgment
- [ ] constellation-down.sh logs usage time and estimated cost
- [ ] CONSTELLATION-CHECKLIST.md exists and is comprehensive
- [ ] constellation-auto-check.sh runs successfully and logs to ~/.constellation-auto-check.log
- [ ] Cron job is scheduled for daily auto-check
- [ ] AWS Budget is created with $15 limit and progressive alerts
- [ ] Usage report script generates accurate summaries
- [ ] SNS email subscription is confirmed (check inbox)
- [ ] All scripts are executable (chmod +x)
- [ ] All verification commands pass

---

## Testing Plan

### Pre-Implementation Test
```bash
# Current state - should be minimal safeguards
ls -la scripts/constellation-*.sh
cat CONSTELLATION-CHECKLIST.md  # Should not exist yet
crontab -l | grep constellation  # Should be empty
```

### Post-Implementation Test
```bash
# 1. Verify all files exist
ls -la scripts/constellation-*.sh
cat CONSTELLATION-CHECKLIST.md

# 2. Verify executability
file scripts/constellation-*.sh | grep executable

# 3. Test auto-check
./scripts/constellation-auto-check.sh
echo $?  # Should be 0 if no infrastructure running

# 4. Test usage report
./scripts/constellation-usage-report.sh

# 5. Verify cron
crontab -l

# 6. Check logs exist
ls -la ~/.constellation-*.log
```

### Integration Test (Actual Deployment)
```bash
# Full cycle test:
# 1. Run constellation-up.sh (should show reminder)
# 2. Note start time
# 3. Wait 5 minutes
# 4. Run constellation-down.sh (should show usage summary)
# 5. Check ~/.constellation-usage.log for entries
# 6. Run usage report to verify calculations
```

---

## Rollback Plan

If any issues arise during implementation:

```bash
# 1. Remove cron job
crontab -l | grep -v constellation | crontab -

# 2. Revert script changes
cd ~/git/internal/repos/carian-constellation
git checkout scripts/constellation-up.sh
git checkout scripts/constellation-down.sh

# 3. Delete budget (if problematic)
aws budgets delete-budget \
  --account-id <aws-account-id> \
  --budget-name constellation-monthly-budget \
  --region us-east-1 --profile constellation-admin-vm

# 4. Remove added files
rm CONSTELLATION-CHECKLIST.md
rm scripts/constellation-auto-check.sh
rm scripts/setup-aws-budget.sh
rm scripts/constellation-usage-report.sh
rm ~/.constellation-*.log
```

---

## Notes

### Important Reminders
- All scripts assume AWS_PROFILE=constellation-admin-vm
- Infrastructure is in us-west-2 (not us-east-1)
- CloudWatch billing metrics only available in us-east-1
- Email confirmation required for SNS subscription
- Cron job needs absolute paths

### Future Enhancements
- Lambda function for automated TTL-based teardown
- Slack webhook integration for real-time alerts
- CloudWatch dashboard for cost visualization
- Terraform workspace for test vs. prod

### Dependencies
- AWS CLI configured with constellation-admin-vm profile
- bc (calculator) for cost calculations
- jq for JSON parsing
- mail/mailx for email alerts (optional)
- cron daemon running

---

## Questions / Blockers

If you encounter issues during implementation:

1. **SNS subscription not confirming**
   - Check spam folder for AWS confirmation email
   - Verify email address in SNS topic subscribers
   - Resend confirmation: `aws sns subscribe ...`

2. **Cron job not running**
   - Check cron daemon: `ps aux | grep cron`
   - Verify crontab syntax: `crontab -l`
   - Check system logs: `/var/log/syslog` or `/var/log/cron`

3. **Scripts failing with AWS errors**
   - Verify AWS credentials: `aws sts get-caller-identity --profile constellation-admin-vm`
   - Check region is correct (us-west-2 for resources, us-east-1 for billing)
   - Ensure IAM permissions for budgets, CloudWatch, SNS

4. **Budget creation fails**
   - Budget might already exist (check console)
   - Verify account ID is correct
   - Check IAM permissions for budgets API

---

## Completion Checklist

When all tasks are done:

- [ ] All scripts created and tested
- [ ] All verification commands pass
- [ ] Documentation updated
- [ ] SNS subscription confirmed
- [ ] Cron job scheduled and verified
- [ ] Usage logs working
- [ ] INCIDENT-2025-11-01-BILLING.md reviewed
- [ ] This handoff document can be archived

**Estimated Completion Time**: 2-3 hours
**Priority**: High (prevents future $350+ incidents)
**Assigned**: [Your Name]
**Target Date**: [Set a deadline]

---

**End of Handoff Document**
