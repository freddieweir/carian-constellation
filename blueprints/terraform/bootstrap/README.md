# Bootstrap Infrastructure

**One-time setup for persistent Carian Constellation resources**

This Terraform module creates the foundational infrastructure that persists even when the constellation is destroyed. These resources are essential for the ephemeral infrastructure to function.

---

## 📦 What Gets Created

### Storage
- **S3 Terraform State Bucket**: Stores Terraform state for ephemeral module
- **S3 Backup Bucket**: Stores constellation data backups
- **DynamoDB Lock Table**: Prevents concurrent Terraform operations

### Networking
- **Route53 Hosted Zone**: DNS management for your domain

### Security
- **Secrets Manager Secrets**: Placeholders for API keys and passwords
- **IAM Policies**: MFA enforcement and access policies

### Cost
**~$5.50/month** for these persistent resources:
- S3: ~$1/month (minimal storage)
- Route53: $0.50/month (hosted zone)
- Secrets Manager: ~$2/month (5 secrets × $0.40)
- DynamoDB: Pay-per-request (minimal usage)

---

## 🚀 Quick Start

### 1. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Fill in your values:
- `domain_name`: Your actual domain
- `owner_email`: Your email
- `github_username`: Your GitHub username

### 2. Deploy

```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Create resources (with MFA)
aws-vault exec constellation -- terraform apply
```

### 3. Save Outputs

```bash
# Save for reference
terraform output -json > bootstrap-outputs.json

# Get nameservers for domain registrar
terraform output route53_nameservers
```

### 4. Configure DNS

Take the nameservers from the output and configure them at your domain registrar:
- GoDaddy: Domain Settings → Nameservers → Custom
- Namecheap: Domain List → Manage → Nameservers → Custom DNS
- Google Domains: DNS → Name servers → Custom name servers

DNS propagation can take up to 48 hours.

### 5. Populate Secrets

```bash
# Generate strong secrets
SESSION_SECRET=$(openssl rand -hex 32)
STORAGE_KEY=$(openssl rand -hex 32)
GRAFANA_PASS=$(openssl rand -base64 32)

# Store in Secrets Manager
aws secretsmanager put-secret-value \
  --secret-id carian-constellation/authelia/session-secret \
  --secret-string "$SESSION_SECRET"

aws secretsmanager put-secret-value \
  --secret-id carian-constellation/authelia/storage-encryption-key \
  --secret-string "$STORAGE_KEY"

aws secretsmanager put-secret-value \
  --secret-id carian-constellation/grafana/admin-password \
  --secret-string "$GRAFANA_PASS"

# Add your API keys
aws secretsmanager put-secret-value \
  --secret-id carian-constellation/api-keys/openai \
  --secret-string "sk-your-openai-key"

aws secretsmanager put-secret-value \
  --secret-id carian-constellation/api-keys/anthropic \
  --secret-string "sk-ant-your-anthropic-key"
```

---

## 📁 Files

- `main.tf` - Provider and core configuration
- `variables.tf` - Input variables
- `s3.tf` - S3 buckets and DynamoDB table
- `route53.tf` - DNS hosted zone
- `secrets.tf` - AWS Secrets Manager
- `iam.tf` - IAM policies and roles
- `outputs.tf` - Output values for ephemeral module
- `terraform.tfvars.example` - Example configuration

---

## 🔒 Security Features

### S3 Buckets
- ✅ Versioning enabled
- ✅ Encryption at rest (AES256)
- ✅ Public access blocked
- ✅ Lifecycle policies for cost optimization

### Secrets
- ✅ 7-day recovery window
- ✅ Comprehensive tagging
- ✅ IAM policy for External Secrets Operator

### IAM
- ✅ MFA enforcement policy
- ✅ Automation role for future CI/CD
- ✅ Least privilege principles

---

## 🏷️ Tagging

All resources are tagged with:
- `Project: CarianConstellation`
- `ManagedBy: Terraform`
- `Environment: persistent`
- `Lifecycle: permanent`
- `Owner: stalheim`
- Plus service-specific tags

---

## 🔄 Updates

To update bootstrap infrastructure:

```bash
# Review changes
terraform plan

# Apply updates
aws-vault exec constellation -- terraform apply
```

**Note**: These resources have `prevent_destroy = true` to avoid accidental deletion.

---

## 🧹 Cleanup

**⚠️ WARNING**: Only destroy bootstrap if you're completely done with Carian Constellation.

```bash
# Remove prevent_destroy protection first
# Edit each .tf file and comment out lifecycle blocks

# Then destroy
terraform destroy
```

This will delete:
- ✅ All Terraform state history
- ✅ All backup data
- ✅ DNS records
- ✅ Secrets

**Make sure you have backups before doing this!**

---

## 📊 Verification

After deployment, verify everything:

```bash
# Check S3 buckets
aws s3 ls | grep carian-constellation

# Check DynamoDB table
aws dynamodb describe-table --table-name carian-constellation-tfstate-lock

# Check Route53 zone
aws route53 list-hosted-zones | grep yourdomain.com

# Check secrets
aws secretsmanager list-secrets --filters Key=name,Values=carian-constellation

# Check DNS propagation (after configuring registrar)
dig NS yourdomain.com
nslookup yourdomain.com
```

---

## 🔗 Next Steps

After bootstrap is complete:

1. ✅ Configure DNS at your registrar (use nameservers from output)
2. ✅ Wait for DNS propagation (up to 48 hours)
3. ✅ Move to ephemeral infrastructure: `cd ../ephemeral`
4. ✅ Configure backend: `terraform init -backend-config=backend.hcl`
5. ✅ Deploy constellation: `../../scripts/constellation-up.sh`

---

## 📚 Resources

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS S3 Backend](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [Route53 Documentation](https://docs.aws.amazon.com/route53/)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
