# Carian Constellation IAM Policies

Least-privilege IAM policies for managing the Carian Constellation infrastructure following AWS security best practices.

## 📋 Policy Overview

This directory contains IAM policies designed with principle of least privilege:

| Policy | File | Purpose | Required For |
|--------|------|---------|-------------|
| **🎯 Combined Policy** | `constellation-iam-policy.json` | **All permissions in one policy (recommended)** | Complete infrastructure management |
| **Bootstrap Infrastructure** | `01-bootstrap-infrastructure.json` | S3 state, DynamoDB locks, Route53, Secrets Manager, base IAM roles | One-time setup |
| **Ephemeral Infrastructure** | `02-ephemeral-infrastructure.json` | EKS cluster, VPC, EC2, Load Balancers, Auto Scaling | Terraform apply/destroy |
| **Kubernetes Operations** | `03-kubernetes-operations.json` | kubectl, Helm, ALB Controller, External Secrets, cert-manager | Day-to-day operations |

**💡 Recommendation**: Use `constellation-iam-policy.json` for simplicity. It combines all three modular policies into a single comprehensive policy (easier to manage, fewer policy attachments).

## 🔐 Security Features

All policies follow AWS security best practices:

✅ **Least Privilege** - Only permissions necessary for specific operations
✅ **Resource Scoping** - Restricted to `constellation-*` named resources where possible
✅ **Condition Keys** - Additional constraints on sensitive operations
✅ **Service-Specific** - Permissions grouped by AWS service and use case
✅ **Auditable** - Clear Sid statements for each permission group

## 🚀 Quick Start

### Automated Setup (Recommended)

```bash
# Run the automated setup script
./create-iam-user.sh

# Or specify a custom username
./create-iam-user.sh my-custom-username
```

**The script will**:
- ✅ Create IAM user
- ✅ Create and attach all 3 policies
- ✅ Generate access key pair
- ✅ Add MFA enforcement policy
- ✅ Display credentials and next steps

### Manual Setup (Alternative)

If you prefer manual setup or need to customize:

#### 1. Create IAM User

```bash
# Create dedicated IAM user for Carian Constellation
aws iam create-user --user-name constellation-admin

# Enable MFA (REQUIRED for security)
# Follow AWS Console steps to attach hardware/virtual MFA device
```

#### 2. Attach Policies

```bash
# Create the policies in AWS
aws iam create-policy \
  --policy-name ConstellationBootstrap \
  --policy-document file://policies/01-bootstrap-infrastructure.json

aws iam create-policy \
  --policy-name ConstellationEphemeral \
  --policy-document file://policies/02-ephemeral-infrastructure.json

aws iam create-policy \
  --policy-name ConstellationKubernetesOps \
  --policy-document file://policies/03-kubernetes-operations.json

# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Attach policies to user
aws iam attach-user-policy \
  --user-name constellation-admin \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/ConstellationBootstrap

aws iam attach-user-policy \
  --user-name constellation-admin \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/ConstellationEphemeral

aws iam attach-user-policy \
  --user-name constellation-admin \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/ConstellationKubernetesOps
```

#### 3. Create Access Keys

```bash
# Create access keys for programmatic access
aws iam create-access-key --user-name constellation-admin

# IMPORTANT: Save the output - you'll only see the secret key once!
# Store in 1Password or AWS Secrets Manager
```

#### 4. Configure AWS CLI

**Option A: Using aws-vault (Recommended for MFA)**
```bash
# Install aws-vault
brew install aws-vault

# Add credentials to aws-vault
aws-vault add constellation

# Use with MFA
aws-vault exec constellation -- terraform plan
aws-vault exec constellation -- kubectl get nodes
```

**Option B: Using AWS CLI profiles**
```bash
# Configure AWS CLI profile
aws configure --profile constellation
# Enter your Access Key ID, Secret Access Key, region (us-east-1)

# Export profile
export AWS_PROFILE=constellation

# Verify access
aws sts get-caller-identity
```

## 📊 Policy Details

### 01-bootstrap-infrastructure.json

**Purpose**: One-time setup of foundational resources
**Resources Created**:
- S3 bucket for Terraform remote state (`constellation-terraform-state-*`)
- DynamoDB table for state locking (`constellation-terraform-locks`)
- Route53 hosted zone for DNS
- AWS Secrets Manager secrets (`constellation/*`)
- IAM policies and roles for IRSA
- KMS keys for encryption

**Permissions**:
- S3: Full bucket lifecycle, object operations
- DynamoDB: Table creation, state locking
- Route53: Hosted zone management
- Secrets Manager: Secret CRUD operations
- IAM: Policy and role creation (scoped to `constellation-*`)
- KMS: Key creation, rotation, encryption/decryption

### 02-ephemeral-infrastructure.json

**Purpose**: Deploy and destroy on-demand EKS cluster infrastructure
**Resources Created**:
- EKS cluster and node groups
- VPC with public/private subnets
- NAT gateway and Internet gateway
- Security groups
- EC2 instances (worker nodes, Tailscale relay)
- Load balancers (ALB)
- Auto Scaling groups
- EBS volumes

**Permissions**:
- EKS: Full cluster lifecycle
- EC2: VPC, instances, networking, volumes
- Auto Scaling: ASG management
- ELB: Load balancer operations
- IAM: PassRole for EKS, service-linked roles
- CloudWatch: Log group management

**Key Constraints**:
- PassRole limited to EKS and EC2 services
- Service-linked roles only for EKS, Auto Scaling, ELB
- Resources scoped to `constellation-*` where possible

### 03-kubernetes-operations.json

**Purpose**: Day-to-day Kubernetes and application management
**Resources Managed**:
- Kubernetes workloads via kubectl/Helm
- AWS Load Balancer Controller (ALB ingress)
- External Secrets Operator (Secrets Manager sync)
- cert-manager (Route53 DNS challenges)
- EBS CSI driver (persistent volumes)
- Data backups to S3

**Permissions**:
- EKS: Read-only cluster access, Kubernetes API access
- Secrets Manager: Read secrets for External Secrets Operator
- ELB: Full ALB lifecycle for ingress controller
- EC2: Volume operations for EBS CSI driver
- Route53: DNS record updates for cert-manager
- S3: Backup/restore operations
- CloudWatch: Metrics publishing

**Key Features**:
- Read-only access to cluster metadata
- Full control over ALB and EBS resources (IRSA controllers)
- Route53 updates for certificate validation
- S3 backup bucket access for data persistence

## 🔒 Security Best Practices

### Mandatory MFA Enforcement

**Add this policy** to require MFA for all operations:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyAllExceptListedIfNoMFA",
      "Effect": "Deny",
      "NotAction": [
        "iam:CreateVirtualMFADevice",
        "iam:EnableMFADevice",
        "iam:GetUser",
        "iam:ListMFADevices",
        "iam:ListVirtualMFADevices",
        "iam:ResyncMFADevice",
        "sts:GetSessionToken"
      ],
      "Resource": "*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    }
  ]
}
```

**Apply to user**:
```bash
# Save the above policy as mfa-enforcement.json
aws iam put-user-policy \
  --user-name constellation-admin \
  --policy-name RequireMFA \
  --policy-document file://mfa-enforcement.json
```

### Additional Recommendations

1. **Use aws-vault** - Automatically handles MFA token caching and session management
2. **Enable CloudTrail** - Audit all IAM actions for security monitoring
3. **Rotate Access Keys** - Every 90 days minimum
4. **Use IRSA** - Service accounts in Kubernetes use IAM roles (no long-lived credentials)
5. **Restrict IP Ranges** - Add source IP conditions for additional security
6. **Monitor Costs** - Set up billing alerts for unexpected usage

## 🛠️ Troubleshooting

### Permission Denied Errors

**Check which policy is needed**:
- Bootstrap operations (Terraform in `bootstrap/`) → Policy 01
- Cluster deployment (Terraform in `ephemeral/` or `persistent/`) → Policies 01 + 02
- Kubernetes operations (kubectl, Helm) → Policy 03
- Application management → Policy 03

**Verify policies are attached**:
```bash
aws iam list-attached-user-policies --user-name constellation-admin
```

**Test specific permissions**:
```bash
# Test S3 state bucket access
aws s3 ls s3://constellation-terraform-state-<unique-id>

# Test EKS cluster access
aws eks describe-cluster --name constellation-dev --region us-east-1

# Test Secrets Manager access
aws secretsmanager list-secrets --region us-east-1 | grep constellation
```

### MFA Issues

**Get temporary credentials with MFA**:
```bash
# Using aws-vault (easiest)
aws-vault exec constellation --duration=12h -- aws sts get-caller-identity

# Using AWS CLI directly
aws sts get-session-token \
  --serial-number arn:aws:iam::ACCOUNT_ID:mfa/constellation-admin \
  --token-code 123456
```

### Permission Too Restrictive

If legitimate operations fail:

1. **Check AWS CloudTrail** for the exact denied action
2. **Update the relevant policy** to include the permission
3. **Create new policy version**:
   ```bash
   aws iam create-policy-version \
     --policy-arn arn:aws:iam::ACCOUNT_ID:policy/ConstellationEphemeral \
     --policy-document file://policies/02-ephemeral-infrastructure.json \
     --set-as-default
   ```

## 📖 Policy Maintenance

### Updating Policies

```bash
# 1. Edit the JSON file locally
vim policies/02-ephemeral-infrastructure.json

# 2. Validate JSON syntax
jq empty policies/02-ephemeral-infrastructure.json

# 3. Create new policy version
POLICY_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/ConstellationEphemeral"

aws iam create-policy-version \
  --policy-arn $POLICY_ARN \
  --policy-document file://policies/02-ephemeral-infrastructure.json \
  --set-as-default

# 4. Delete old versions (AWS limits to 5 versions)
aws iam list-policy-versions --policy-arn $POLICY_ARN
aws iam delete-policy-version --policy-arn $POLICY_ARN --version-id v1
```

### Auditing Permissions

```bash
# List all permissions for user
aws iam get-user-policy --user-name constellation-admin --policy-name RequireMFA
aws iam list-attached-user-policies --user-name constellation-admin

# Simulate policy to test permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT_ID:user/constellation-admin \
  --action-names eks:DescribeCluster s3:ListBucket \
  --resource-arns arn:aws:eks:us-east-1:ACCOUNT_ID:cluster/constellation-dev
```

## 🔗 Related Documentation

- [../blueprints/DEPLOYMENT_GUIDE.md](../blueprints/DEPLOYMENT_GUIDE.md) - Full deployment workflow
- [../blueprints/terraform/bootstrap/README.md](../blueprints/terraform/bootstrap/README.md) - Bootstrap Terraform module
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)

## 📝 Notes

- These policies are designed for **personal/development use**
- For production environments, consider additional restrictions:
  - IP source conditions
  - Time-based access
  - Service Control Policies (SCPs) in AWS Organizations
  - Permission boundaries
- All policies follow the principle of least privilege
- Resource scoping uses `constellation-*` naming pattern for easy identification
- Policies are versioned and can be updated without recreating
