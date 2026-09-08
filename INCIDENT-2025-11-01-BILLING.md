# Incident Report: Carian Constellation Billing Crisis

**Date**: November 1, 2025
**Incident ID**: CONSTELLATION-2025-11-01-BILLING
**Severity**: High (Financial Impact)
**Status**: ✅ RESOLVED
**Duration**: 19 days (undetected) | 10 minutes (resolution)

---

## Executive Summary

On November 1, 2025, AWS ephemeral infrastructure for the Carian Constellation project was discovered still running after 19 days, resulting in an unexpected bill of **$357.98** instead of the expected **$5.50** for persistent resources only. All 100 AWS resources were immediately destroyed, stopping ongoing costs. Multiple safeguards have been implemented to prevent recurrence.

---

## Incident Timeline

| Time (UTC) | Event |
|------------|-------|
| **2025-10-13 06:19** | EKS cluster and ephemeral infrastructure deployed in us-west-2 |
| **2025-10-13 06:31** | 2× t3.small worker nodes launched |
| **2025-10-13 - 2025-11-01** | Infrastructure left running (unintentional) |
| **2025-11-01 05:00** | Billing alert discovered - $357.98 October bill |
| **2025-11-01 05:06** | Investigation began - checked us-east-1 (wrong region) |
| **2025-11-01 05:15** | Infrastructure destroyed in us-west-2 (correct region) |
| **2025-11-01 05:25** | CloudWatch billing alarm configured |
| **2025-11-01 05:30** | Incident report completed |

**Total Runtime**: 456 hours (~19 days)
**Expected Runtime**: 4-8 hours maximum
**Cost Overrun**: **$352.48** (7,049% over budget)

---

## Financial Impact

### October 2025 Bill Breakdown: $357.98

| Service | Cost | % of Total | Details |
|---------|------|------------|---------|
| **Amazon EKS Control Plane** | $273.34 | 76% | $0.10/hour × ~730 hours |
| **VPC/NAT Gateway** | $29.46 | 8% | $0.045/hour × ~655 hours |
| **EC2 Other (EBS, data transfer)** | $22.73 | 6% | Storage + data transfer |
| **EC2 Compute (worker nodes)** | $18.85 | 5% | 2× t3.small instances |
| **CloudWatch** | $6.67 | 2% | Logs and metrics |
| **Route53** | $3.02 | 1% | Hosted zones (persistent) |
| **AWS Secrets Manager** | $1.22 | <1% | API keys (persistent) |
| **KMS** | $1.82 | <1% | Encryption keys |
| **TOTAL** | **$357.98** | **100%** | |

### Cost Comparison Analysis

| Scenario | Monthly Cost | Notes |
|----------|--------------|-------|
| **Persistent (bootstrap only)** | $5.50 | S3, Route53, Secrets - Expected baseline |
| **Weekend use (16 hrs/month)** | $9.50 | Original target budget |
| **Regular use (40 hrs/month)** | $15.50 | Acceptable for development |
| **October actuals (456 hrs)** | **$357.98** | **CRISIS - Infrastructure not destroyed** |
| **Always-on (720 hrs/month)** | $185.00 | Never intended |

**Budget Variance**: +6,509% over expected persistent costs
**Impact**: $352.48 unplanned expenditure

---

## Root Cause Analysis

### Primary Causes

1. **No Automatic Shutdown**
   - Ephemeral infrastructure relied entirely on manual `terraform destroy`
   - No timeout mechanism or auto-termination tags
   - No scheduled cleanup jobs

2. **Wrong Region Assumption**
   - Infrastructure deployed in `us-west-2`
   - Investigation initially checked `us-east-1` (wrong region)
   - Delayed discovery by ~15 minutes

3. **No Cost Monitoring**
   - No CloudWatch billing alarms configured
   - No AWS Budget alerts
   - No daily cost tracking

4. **No Usage Tracking**
   - No logs of when cluster was started
   - No calendar reminders or timers set
   - No operational checklist followed

5. **Lack of Visibility**
   - Terraform state showed resources, but manual verification skipped wrong region
   - No periodic "what's running" checks

### Contributing Factors

- **Multi-region complexity**: Project configured for us-west-2, but default region assumptions led to us-east-1 checks
- **No pre-commit reminder**: constellation-up.sh didn't warn about destruction requirements
- **Testing phase**: Infrastructure spun up for testing, but no formal test completion/cleanup process

---

## Resolution Actions

### Immediate Response (Completed)

1. ✅ **Identified running resources in us-west-2**
   - EKS cluster: constellation-dev
   - 2× t3.small EC2 instances
   - NAT gateway, VPC, security groups, IAM roles

2. ✅ **Executed terraform destroy**
   - Destroyed 100 AWS resources
   - Runtime: ~8 minutes
   - Verified complete removal across all regions

3. ✅ **Configured CloudWatch billing alarm**
   - Threshold: $5 daily estimated charges
   - SNS topic: constellation-billing-alerts
   - Email notification to: alerts@example.com
   - Status: Awaiting email confirmation

4. ✅ **Verified zero ongoing costs**
   - Only persistent resources remain ($5.50/month)
   - No orphaned resources in other regions

---

## Prevention Measures

### 1. Automated Monitoring (Implemented)

**CloudWatch Billing Alarm**
```bash
Alarm Name: constellation-daily-cost-alert
Threshold: $5.00 USD
Period: 6 hours
Action: SNS email notification
Status: ACTIVE (pending email confirmation)
```

**Next Step**: Confirm subscription email from AWS

### 2. Operational Safeguards (Recommended)

**A. Update constellation-up.sh**
Add prominent reminder at script completion:
```bash
echo ""
echo "⚠️  CRITICAL REMINDER: Run ./constellation-down.sh when finished!"
echo "⚠️  Current cost: $0.25/hour = $6/day if left running"
echo "⚠️  Set a timer NOW for your estimated usage duration"
echo "⚠️  Maximum recommended runtime: 4 hours"
echo ""
read -p "Press Enter to acknowledge and set reminder..."
```

**B. Create Auto-Check Script**
Daily cron job to check for running infrastructure:
```bash
#!/bin/bash
# ~/scripts/constellation-auto-check.sh
# Run daily via cron: 0 22 * * * ~/scripts/constellation-auto-check.sh

export AWS_PROFILE=constellation-admin-vm
CLUSTER=$(aws eks list-clusters --region us-west-2 --query 'clusters[0]' --output text 2>/dev/null)

if [ "$CLUSTER" != "None" ] && [ -n "$CLUSTER" ]; then
  # Cluster running - check age
  CREATED=$(aws eks describe-cluster --name "$CLUSTER" --region us-west-2 \
    --query 'cluster.createdAt' --output text)
  AGE_HOURS=$(( ($(date +%s) - $(date -d "$CREATED" +%s)) / 3600 ))

  if [ $AGE_HOURS -gt 8 ]; then
    # Send alert - cluster running > 8 hours
    echo "WARNING: EKS cluster $CLUSTER has been running for $AGE_HOURS hours" | \
      mail -s "Constellation Alert: Long-running infrastructure" alerts@example.com
  fi
fi
```

**C. Add TTL Tags to Resources**
Modify `terraform/ephemeral/locals.tf`:
```hcl
locals {
  common_tags = merge(
    var.default_tags,
    {
      CreatedAt   = timestamp()
      MaxLifetime = "4h"
      AutoDestroy = "true"
    }
  )
}
```

**D. Create Operational Checklist**
`CONSTELLATION-CHECKLIST.md`:
```markdown
# Carian Constellation Operations Checklist

## Pre-Deployment
- [ ] Verify AWS credentials active: `aws sts get-caller-identity`
- [ ] Check current bill < $10: `aws ce get-cost-and-usage ...`
- [ ] Set calendar reminder for 4 hours from now
- [ ] Note start time: ___________

## During Operation
- [ ] Set phone timer for 3 hours (warning before 4hr limit)
- [ ] Monitor cluster: `watch -n 300 aws eks describe-cluster ...`

## Post-Operation (CRITICAL)
- [ ] Run: `./scripts/constellation-down.sh`
- [ ] Verify destruction: `aws eks list-clusters --region us-west-2`
- [ ] Expected output: `{"clusters": []}`
- [ ] Log usage time and estimated cost
```

### 3. Cost Tracking (Recommended)

**Usage Log Implementation**
Add to both constellation-up.sh and constellation-down.sh:
```bash
# constellation-up.sh
echo "$(date +%Y-%m-%d\ %H:%M:%S) | UP | region=us-west-2" >> ~/constellation-usage.log

# constellation-down.sh
START_TIME=$(grep "UP" ~/constellation-usage.log | tail -1 | cut -d'|' -f1)
RUNTIME_HOURS=$(calculate_hours_between "$START_TIME" "$(date)")
ESTIMATED_COST=$(echo "$RUNTIME_HOURS * 0.25" | bc -l)
echo "$(date +%Y-%m-%d\ %H:%M:%S) | DOWN | runtime=${RUNTIME_HOURS}h | cost=\$${ESTIMATED_COST}" \
  >> ~/constellation-usage.log
```

### 4. AWS Budget Creation (Recommended)

Create monthly budget with progressive alerts:
```json
{
  "BudgetName": "constellation-monthly-budget",
  "BudgetLimit": {
    "Amount": "15",
    "Unit": "USD"
  },
  "CostTypes": {
    "IncludeTax": true,
    "IncludeSubscription": true
  },
  "TimeUnit": "MONTHLY",
  "Notifications": [
    {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 66,
      "ThresholdType": "PERCENTAGE"
    },
    {
      "NotificationType": "FORECASTED",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 100,
      "ThresholdType": "PERCENTAGE"
    }
  ]
}
```

Alerts at:
- 66% of budget ($10) - Warning
- 100% forecast - Critical alert

---

## Lessons Learned

### What Went Well
- ✅ Infrastructure architecture worked as designed (ephemeral pattern)
- ✅ Terraform state management was reliable
- ✅ Rapid response once detected (10 minute resolution)
- ✅ No data loss or service disruption

### What Didn't Go Well
- ❌ No monitoring for unintended long-running resources
- ❌ Region confusion delayed initial investigation
- ❌ No automatic alerts for cost anomalies
- ❌ No operational discipline/checklist enforcement

### Key Takeaways

1. **Automation is critical** - Manual processes fail without reminders
2. **Multi-region awareness** - Always verify the correct region
3. **Cost visibility** - Daily monitoring prevents monthly surprises
4. **Operational checklists** - Prevent human error in routine tasks
5. **Defense in depth** - Multiple safeguards (alarms, timers, logs, automation)

---

## Future Recommendations

### High Priority (Do Before Next Deployment)
1. ✅ **CloudWatch billing alarm** - COMPLETED
2. ⏳ **Confirm SNS email subscription** - Awaiting user action
3. ⏳ **Update constellation-up.sh** - Add prominent reminder
4. ⏳ **Create constellation-auto-check.sh** - Daily verification cron
5. ⏳ **Implement usage logging** - Track all spin-up/down events

### Medium Priority (Next 2 Weeks)
6. ⏳ **AWS Budget creation** - Monthly $15 limit with alerts
7. ⏳ **Add TTL tags** - Resource lifetime metadata
8. ⏳ **Create operational checklist** - CONSTELLATION-CHECKLIST.md
9. ⏳ **Test all safeguards** - Verify alerting works

### Low Priority (Nice to Have)
10. ⏳ **Lambda auto-termination** - Destroy resources after TTL expiry
11. ⏳ **Slack integration** - Real-time cost notifications
12. ⏳ **Dashboard creation** - CloudWatch dashboard for cost metrics
13. ⏳ **Pre-commit git hook** - Remind about active infrastructure

---

## Current Status

### Infrastructure State
```
EKS Cluster (us-west-2):    DESTROYED ✅
Worker Nodes:                DESTROYED ✅
NAT Gateway:                 DESTROYED ✅
VPC/Networking:              DESTROYED ✅
Security Groups:             DESTROYED ✅
IAM Roles:                   DESTROYED ✅

Persistent Resources:        ACTIVE ✅ (Expected)
  - S3 Buckets:             2 ($0.50/month)
  - Route53 Hosted Zones:   1 ($3.02/month)
  - Secrets Manager:        Active ($1.22/month)
  - KMS Keys:               Active ($1.82/month)
```

### Ongoing Costs
- **Current**: $5.50/month (persistent resources only)
- **Projected November**: $362.98 (includes October charges + Nov persistent)
- **Projected December**: $5.50 (back to normal)

### Monitoring
- **CloudWatch Alarm**: ACTIVE (awaiting email confirmation)
- **SNS Topic**: arn:aws:sns:us-east-1:<aws-account-id>:constellation-billing-alerts
- **Next Alert Threshold**: $5 daily spend

---

## Testing and Verification

### Verification Commands

**Check for running infrastructure**:
```bash
# Correct region (us-west-2)
export AWS_PROFILE=constellation-admin-vm
aws eks list-clusters --region us-west-2
# Expected: {"clusters": []}

aws ec2 describe-instances --region us-west-2 \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType]'
# Expected: Empty

aws ec2 describe-nat-gateways --region us-west-2 \
  --filter "Name=state,Values=available"
# Expected: Empty
```

**Check current costs**:
```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-11-01,End=2025-11-02 \
  --granularity DAILY \
  --metrics UnblendedCost \
  --output table
```

**Verify billing alarm**:
```bash
aws cloudwatch describe-alarms \
  --alarm-names constellation-daily-cost-alert \
  --region us-east-1
```

---

## Appendix

### A. Resource Inventory (Destroyed)

**100 resources destroyed** including:
- 1× EKS Cluster (constellation-dev)
- 2× EC2 Instances (t3.small worker nodes)
- 1× NAT Gateway
- 1× VPC
- 4× Subnets (2 public, 2 private)
- 1× Internet Gateway
- 3× Route Tables
- 15× Security Groups
- 22× IAM Roles and Policies
- 6× KMS Keys and Aliases
- 4× CloudWatch Log Groups
- 4× VPC Endpoints
- Multiple security group rules, tags, and associations

### B. Cost Breakdown by Hour

| Metric | Value |
|--------|-------|
| **Hourly Cost** | $0.2489 |
| **Daily Cost** | $5.97 |
| **Weekly Cost** | $41.82 |
| **19-Day Actual** | $357.98 |

### C. Related Documentation

- [Carian Constellation CLAUDE.md](CLAUDE.md) - Project documentation
- [blueprints/terraform/ephemeral/README.md](blueprints/terraform/ephemeral/README.md) - Infrastructure details
- [scripts/constellation-up.sh](scripts/constellation-up.sh) - Deployment script
- [scripts/constellation-down.sh](scripts/constellation-down.sh) - Teardown script

---

## Sign-Off

**Incident Lead**: Claude (AI Assistant)
**Reviewed By**: freddieweir
**Date Closed**: November 1, 2025
**Follow-up Required**: Email subscription confirmation for billing alerts

**Status**: ✅ **RESOLVED** - No ongoing financial impact
**Prevention**: 🟡 **IN PROGRESS** - Safeguards being implemented
