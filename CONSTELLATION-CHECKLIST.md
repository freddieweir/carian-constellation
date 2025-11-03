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
- **Email**: aws@freddieweir.com (confirm SNS subscription)
- **Usage Log**: ~/.constellation-usage.log
- **Auto-Check Script**: Runs daily at 10 PM

---

## Quick Reference Commands

```bash
# Deploy infrastructure
cd ~/git/internal/repos/carian-constellation
./scripts/constellation-up.sh

# Tear down infrastructure
./scripts/constellation-down.sh

# Check current status
aws eks list-clusters --region us-west-2 --profile constellation-admin-vm

# View usage report
./scripts/constellation-usage-report.sh

# Manual auto-check
./scripts/constellation-auto-check.sh
```
