# GitHub Actions Workflows for Carian Constellation

This directory contains comprehensive CI/CD workflows for the Carian Constellation Kubernetes/Terraform/AWS infrastructure project.

## 📋 Workflow Overview

| Workflow | Trigger | Purpose | Key Tools |
|----------|---------|---------|-----------|
| **terraform-plan.yml** | PR on `blueprints/terraform/**` | Terraform validation, planning, security scanning | terraform, tfsec, checkov, terraform-docs |
| **kubernetes-lint.yml** | PR/Push on `blueprints/kubernetes/**` | Kubernetes manifest validation and linting | kubeval, kubeconform, kube-linter, yamllint, trivy |
| **secret-scanner.yml** | PR/Push | Secret detection and credential validation | gitleaks, trufflehog |
| **aws-security.yml** | PR/Push on `blueprints/terraform/**` | AWS security compliance and cost estimation | terraform-compliance, trivy, custom policies |
| **dependency-check.yml** | PR/Push/Weekly | Dependency security and SBOM generation | pip-audit, safety, actionlint |

## 🏗️ Terraform Workflows

### terraform-plan.yml

**Comprehensive Terraform validation and planning workflow**

**Jobs:**
1. **terraform-validate** - Format check, init, validate across all modules (bootstrap, ephemeral, persistent)
2. **terraform-plan** - Generate plan output for syntax validation (no backend state)
3. **tfsec-scan** - Security scanning for Terraform code with SARIF output
4. **checkov-scan** - Infrastructure security analysis with Checkov
5. **terraform-docs** - Ensure README.md documentation exists for all modules

**Configuration Files:**
- [.tflint.hcl](../../.tflint.hcl) - TFLint configuration with AWS rules
- `terraform.tfvars.example` - Example variable files (actual `.tfvars` are gitignored)

**Key Features:**
- Matrix strategy runs validation across all 3 Terraform modules simultaneously
- Comments PR with validation results
- Security scan results uploaded to GitHub Security tab (if enabled)
- No AWS credentials required (syntax validation only)

## ☸️ Kubernetes Workflows

### kubernetes-lint.yml

**Multi-tool Kubernetes manifest validation**

**Jobs:**
1. **kubeval** - Schema validation against Kubernetes API versions
2. **kubeconform** - Enhanced schema validation with CRD support
3. **kube-linter** - Security and best practices linting
4. **kustomize-build** - Test kustomize builds (if kustomization files exist)
5. **helm-lint** - Helm chart validation (if charts exist)
6. **yaml-lint** - YAML syntax validation with yamllint
7. **manifest-security** - Trivy security scanning for Kubernetes configs
8. **namespace-validation** - Validate namespace structure, NetworkPolicies, ResourceQuotas

**Configuration Files:**
- `.kube-linter.yaml` - Generated during workflow with custom rules
- `.yamllint` - Generated during workflow with custom rules

**Key Features:**
- Validates manifests against Kubernetes 1.28.0 API
- Checks for Zero Trust compliance (NetworkPolicies)
- Validates cost control measures (ResourceQuotas)
- SARIF output for security findings

## 🔐 Security Workflows

### secret-scanner.yml

**Multi-layer secret detection**

**Jobs:**
1. **gitleaks** - Pattern-based secret scanning with custom rules
2. **trufflehog** - Verified secret scanning
3. **terraform-secrets** - Terraform-specific credential validation
4. **kubernetes-secrets** - Kubernetes secret best practices (External Secrets)
5. **aws-credentials** - AWS credential pattern detection

**Custom Detection Patterns:**
- AWS Access Keys, Secret Keys, Session Tokens
- Terraform AWS provider credentials
- Kubernetes inline secrets (warns to use External Secrets Operator)
- Tailscale auth keys
- YubiKey OTP secrets
- Domain exposure (yourdomain.com vs actual domains)

**Configuration Files:**
- [.gitleaksignore](../../.gitleaksignore) - False positive exemptions
- `.gitleaks.toml` - Generated during workflow with custom rules

### aws-security.yml

**AWS-specific security and compliance**

**Jobs:**
1. **terraform-compliance** - Policy-as-code compliance testing
2. **trivy-iac** - Infrastructure-as-code security scanning
3. **cost-estimation** - Manual cost analysis and optimization recommendations
4. **resource-limits** - Validate Kubernetes resource quotas and limits
5. **zero-trust-validation** - Validate Zero Trust architecture components

**Compliance Policies:**
- AWS resource tagging requirements (Owner, Project, Environment, ManagedBy, Lifecycle)
- Security group restrictions (no unrestricted ingress)
- Encryption at rest requirements (EBS, S3, RDS)
- VPC security (private subnets, flow logs)
- EKS security (private endpoints, logging)

**Zero Trust Validation Checks:**
- Tailscale VPN configuration
- Private EKS endpoints
- Kubernetes NetworkPolicies
- External Secrets Operator usage
- Authelia authentication gateway

**Cost Estimate Output:**
- Persistent infrastructure: ~$5.50/month
- Ephemeral infrastructure: ~$0.25/hour
- Usage scenarios: Weekend ($9.50), Regular ($15.50), Always-on ($185.50)
- Optimization opportunities (SPOT instances, VPN alternatives)

### dependency-check.yml

**Dependency security and supply chain**

**Jobs:**
1. **terraform-dependencies** - Terraform provider version checking
2. **python-dependencies** - Python package security (pip-audit, safety)
3. **container-security** - Dockerfile security scanning
4. **github-actions-security** - GitHub Actions version and security validation
5. **aws-sdk-versions** - AWS SDK version consistency
6. **license-compliance** - License file and header validation
7. **sbom-generation** - Software Bill of Materials generation

**Key Features:**
- Weekly scheduled runs (Sunday 00:00)
- Checks for unpinned action versions
- Validates deprecated resource usage
- Generates CycloneDX SBOM format

## 🎯 Local Development

### Pre-commit Hooks

Install pre-commit hooks for local validation before commits:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

**Pre-commit Configuration:** [.pre-commit-config.yaml](../../.pre-commit-config.yaml)

**Hooks Included:**
- Terraform formatting, validation, docs, linting, security (tfsec)
- YAML syntax validation
- File cleanup (trailing whitespace, end-of-file)
- Secret detection (gitleaks)
- Python formatting (black) and linting (flake8)
- Shell script validation (shellcheck)
- Custom checks:
  - Prevent .tfvars commits
  - Detect AWS credentials
  - Warn on inline Kubernetes secrets
  - Validate AWS resource tagging
  - Verify ephemeral resource tagging

## 🔧 Configuration Files Reference

| File | Purpose | Location |
|------|---------|----------|
| `.pre-commit-config.yaml` | Pre-commit hook configuration | Repository root |
| `.tflint.hcl` | TFLint rules and AWS plugin config | Repository root |
| `.gitleaksignore` | Gitleaks false positive exemptions | Repository root |
| `.gitignore` | Git ignore patterns for sensitive files | Repository root |

## 🚀 Workflow Usage

### For Pull Requests

All workflows run automatically on PRs targeting `main`:

```bash
git checkout -b feature/my-changes
# Make changes to blueprints/terraform/ or blueprints/kubernetes/
git add .
git commit -m "feat: add new feature"
git push origin feature/my-changes
# Create PR - workflows run automatically
```

### For Direct Commits

Secret scanning and security checks run on pushes to `main`:

```bash
git checkout main
git pull
# Make changes
git add .
git commit -m "fix: update configuration"
git push  # Requires YubiKey tap (Igris enforcement)
```

### Manual Workflow Runs

Some workflows support manual triggering via GitHub Actions UI or API.

## 🛡️ Security Integration

### Igris YubiKey Enforcement

This repository is configured with **Igris** hardware-enforced git security:

- **Pre-push hooks** require YubiKey tap before pushing to remote
- **Challenge-response** via HMAC-SHA1 on YubiKey OTP slot 2
- **Audit logging** to `~/.tomb-yubikey-verifications.log`
- **Workspace integration** - automatically updated via Igris config

**Configuration:** [igris/configs/yubikey-enforcement.yml](../../../igris/configs/yubikey-enforcement.yml)

### GitHub Security Features

**Enabled:**
- Dependabot alerts (automatic)
- Secret scanning (GitHub native + custom workflows)
- Code scanning (SARIF upload from multiple tools)

**SARIF Uploads:**
- TFSec (Terraform security)
- Checkov (infrastructure security)
- Trivy (Kubernetes and IaC security)
- Kube-linter (Kubernetes best practices)
- Semgrep (static analysis - if enabled)

## 📊 Workflow Artifacts

Workflows generate and upload various artifacts:

| Artifact | Workflow | Retention | Purpose |
|----------|----------|-----------|---------|
| `terraform-plan-{module}` | terraform-plan.yml | 5 days | Terraform plan output for review |
| `cost-estimate` | aws-security.yml | 30 days | Cost analysis and optimization |
| `sbom` | dependency-check.yml | 90 days | Software Bill of Materials |

## 🔄 Workflow Maintenance

### Updating Workflows

1. Make changes to workflow files in `.github/workflows/`
2. Test with PR to ensure validation works
3. Update this README.md if adding new workflows or jobs

### Updating Dependencies

**Terraform Provider Versions:**
- Update in `blueprints/terraform/{module}/versions.tf`
- Run `terraform init -upgrade`

**GitHub Actions:**
- Check for updated action versions quarterly
- Consider pinning to commit SHAs for security

**Pre-commit Hooks:**
- Update `.pre-commit-config.yaml` rev tags
- Run `pre-commit autoupdate`

## 📚 Additional Documentation

- [Main Project Documentation](../../README.md)
- [Terraform Bootstrap README](../../blueprints/terraform/bootstrap/README.md)
- [Terraform Ephemeral README](../../blueprints/terraform/ephemeral/README.md)
- [Kubernetes Manifests README](../../blueprints/kubernetes/README.md)
- [Igris Security System](../../../igris/README.md)

## 🎯 Portfolio Value

These workflows demonstrate:

✅ **SRE Best Practices** - Automated validation, security scanning, cost optimization
✅ **Security Engineering** - Multi-layer secret detection, compliance policies, Zero Trust validation
✅ **DevOps Maturity** - Pre-commit hooks, comprehensive CI/CD, SBOM generation
✅ **Cloud Security** - AWS-specific compliance, infrastructure security scanning
✅ **Kubernetes Expertise** - Multi-tool validation, best practices enforcement
✅ **Cost Optimization** - Automated cost estimation, resource limit validation
✅ **Supply Chain Security** - Dependency scanning, license compliance, SBOM

## 🆘 Troubleshooting

### Workflow Failures

**Terraform validation fails:**
- Check `.terraform/` is gitignored
- Verify all `.tfvars` files use `.example` suffix
- Ensure no hardcoded credentials

**Kubernetes validation fails:**
- Validate YAML syntax with `yamllint`
- Check API versions match Kubernetes 1.28.0
- Ensure NetworkPolicies exist for Zero Trust

**Secret scanner fails:**
- Check if false positive - add to `.gitleaksignore`
- Remove actual secrets, use AWS Secrets Manager
- Verify template files use `yourdomain.com`

**Pre-commit fails:**
- Update pre-commit hooks: `pre-commit autoupdate`
- Skip hook temporarily: `SKIP=terraform_validate git commit`
- Clear cache: `pre-commit clean`

### Local Development Issues

**Pre-commit installation fails:**
```bash
pip install --user pre-commit
pre-commit install
```

**TFLint not found:**
```bash
brew install tflint
tflint --init
```

**Gitleaks not installed:**
```bash
brew install gitleaks
# or
wget https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_*_darwin_arm64.tar.gz
```

---

**Last Updated:** 2025-10-02
**Maintained By:** Carian Constellation Infrastructure Team
**For Questions:** See [CLAUDE.md](../../CLAUDE.md) for project guidance
