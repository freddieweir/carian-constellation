# 🌌 Carian Constellation

**Where each Kubernetes node shines like a star in the constellation** ✨

An AWS EKS-based AI platform demonstrating enterprise-grade SRE practices with Zero Trust security, ephemeral infrastructure, and cost optimization.

[![Infrastructure](https://img.shields.io/badge/Infrastructure-AWS%20EKS-orange)](https://aws.amazon.com/eks/)
[![Security](https://img.shields.io/badge/Security-Zero%20Trust-green)](https://www.cloudflare.com/learning/security/glossary/what-is-zero-trust/)
[![IaC](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)
[![Cost](https://img.shields.io/badge/Cost-$10--15%2Fmonth-blue)](#cost-breakdown)

---

## 🎯 What Is This?

Carian Constellation is a production-grade Kubernetes platform that showcases:

- ✅ **Ephemeral Infrastructure**: Spin up/down entire EKS clusters in minutes
- ✅ **Zero Trust Security**: Multi-layer defense with hardware MFA (YubiKey)
- ✅ **Cost Optimization**: 85% cost reduction through smart architecture
- ✅ **Enterprise Patterns**: Real-world SRE practices for job interviews
- ✅ **Full Automation**: One-command deployment and teardown

### Services Included

| Service | Purpose | Access |
|---------|---------|--------|
| **Open-WebUI** | AI chat interface (supports multiple LLMs) | webui.yourdomain.com |
| **Perplexica** | AI-powered search engine | perplexica.yourdomain.com |
| **Authelia** | Authentication with YubiKey | auth.yourdomain.com |
| **Grafana** | Monitoring & metrics visualization | monitoring.yourdomain.com |
| **Homepage** | Unified dashboard | homepage.yourdomain.com |

---

## 🏗️ Architecture Overview

```
Your Laptop (with YubiKey) 
       │
       └──> Tailscale VPN (Zero Trust)
                  │
                  ▼
            AWS VPC (Private)
                  │
                  ├──> EKS Cluster (Private Endpoint)
                  │    └──> AI Services, Monitoring
                  │
                  └──> Internal ALB
                       └──> Authelia (YubiKey Required)
```

### Key Features

**Ephemeral Infrastructure**:
- Entire cluster created in 12-18 minutes
- Destroyed in 5-8 minutes
- Data backed up to S3 automatically
- Pay only when running

**Security Layers**:
1. **Network**: Tailscale Zero Trust VPN
2. **Infrastructure**: AWS IAM with mandatory MFA
3. **Application**: Authelia with YubiKey WebAuthn
4. **Service**: Kubernetes RBAC

---

## 💰 Cost Breakdown

### Running Costs
```
Hourly rate: $0.25/hour
Daily (24h): $6.00
```

### Monthly Costs by Usage

| Usage Pattern | Hours/Month | Total Cost |
|---------------|-------------|------------|
| **Weekend Projects** | 16 hours | **$9.50** |
| **Regular Use** | 40 hours | **$15.50** |
| **Heavy Use** | 100 hours | **$30.50** |

**Persistent storage**: ~$5.50/month (S3, Route53, Secrets Manager)

**Comparison**: Always-on EKS would cost **$110-145/month** 🎉

---

## 🚀 Quick Start

### Prerequisites

- AWS Account with billing configured
- Terraform 1.5+
- kubectl
- aws-cli configured with MFA
- Tailscale account (free)
- YubiKey (for application access)
- Domain name

### One-Time Setup

```bash
# 1. Clone repository
cd "/Volumes/My Shared Files/macOS Dev Files stalheim/Carian Constellation"

# 2. Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up

# 3. Configure AWS credentials with MFA
aws configure

# 4. Bootstrap persistent infrastructure
cd terraform/bootstrap
terraform init
terraform apply

# 5. Configure your variables
cd ../ephemeral
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your domain, email, etc.
```

### Daily Usage

```bash
# Spin up constellation (12-18 minutes)
./scripts/constellation-up.sh

# Use your services! 🌟
# Access via: https://webui.yourdomain.com

# Tear down when done (5-8 minutes)
./scripts/constellation-down.sh

# Check status anytime
./scripts/constellation-status.sh

# Track costs
./scripts/cost-tracker.sh
```

---

## 🔒 Security Model

### Zero Trust Architecture

**Network Access**:
- ✅ Private EKS endpoint (no public access)
- ✅ Tailscale VPN required for all connections
- ✅ Only your authorized devices can access

**Infrastructure Access**:
- ✅ AWS IAM with mandatory MFA
- ✅ Temporary credentials via aws-vault
- ✅ Client certificates for kubectl

**Application Access**:
- ✅ Authelia with WebAuthn/FIDO2
- ✅ YubiKey tap required for every login
- ✅ No password-only access allowed

**Data Protection**:
- ✅ Encryption at rest (KMS)
- ✅ Encryption in transit (TLS everywhere)
- ✅ Automated backups to S3

---

## 📊 What This Demonstrates

### For SRE Interviews

✅ **Infrastructure as Code**: Terraform with modules, remote state, tagging  
✅ **Kubernetes Expertise**: Production EKS, IRSA, External Secrets, ingress  
✅ **Security Engineering**: Zero Trust, hardware MFA, encryption, RBAC  
✅ **Cost Optimization**: Ephemeral infrastructure, right-sizing, monitoring  
✅ **Site Reliability**: Backup/restore, monitoring, automation, disaster recovery  
✅ **Cloud Native**: AWS services integration, service mesh patterns  

### Resume Talking Points

**"How do you optimize cloud costs?"**
> "I implemented ephemeral infrastructure on AWS EKS, reducing costs by 85% through automated spin-up/down cycles, right-sized instances, and comprehensive cost tracking. The platform costs $10-15/month for regular use versus $110+ for always-on."

**"Describe your approach to security"**
> "I implemented defense-in-depth with Zero Trust principles: network isolation via Tailscale VPN, hardware MFA using YubiKey WebAuthn, private EKS endpoints, AWS IAM with mandatory MFA, and encryption everywhere. This creates four distinct security layers."

**"Tell me about your Kubernetes experience"**
> "I built a production-grade EKS platform with IRSA for service accounts, External Secrets Operator for secret management, internal ALB ingress, and comprehensive monitoring with Prometheus/Grafana/Loki. The platform demonstrates GitOps principles and Infrastructure as Code."

---

## 📁 Project Structure

```
carian-constellation/
├── terraform/
│   ├── bootstrap/          # One-time setup (S3, Route53, etc.)
│   └── ephemeral/          # Spin up/down (EKS, VPC, nodes)
├── kubernetes/
│   ├── manifests/          # Service deployments
│   └── helm-values/        # Helm configurations
├── scripts/
│   ├── constellation-up.sh     # 🚀 Deploy everything
│   ├── constellation-down.sh   # 💥 Destroy everything
│   └── security/               # Security setup scripts
└── docs/                   # Detailed documentation
```

---

## 🛠️ Technology Stack

**Infrastructure**:
- AWS EKS 1.28
- Terraform
- Tailscale Zero Trust VPN
- 2x t3.small nodes

**Security**:
- Authelia (WebAuthn)
- YubiKey (FIDO2)
- AWS Secrets Manager
- KMS encryption

**Monitoring**:
- Prometheus (metrics)
- Grafana (visualization)
- Loki (logs)
- Alertmanager (alerts)

**Services**:
- Open-WebUI (AI chat)
- Perplexica (AI search)
- Homepage (dashboard)
- Glance (feeds)

---

## 📚 Documentation

- [**PROJECT_CONTEXT.md**](PROJECT_CONTEXT.md) - Full technical context for continuity
- [**DEPLOYMENT_GUIDE.md**](DEPLOYMENT_GUIDE.md) - Step-by-step deployment
- [**docs/architecture.md**](docs/architecture.md) - Detailed architecture
- [**docs/security-model.md**](docs/security-model.md) - Security implementation
- [**docs/cost-optimization.md**](docs/cost-optimization.md) - Cost strategies
- [**docs/troubleshooting.md**](docs/troubleshooting.md) - Common issues

---

## 🔄 Workflow Example

```bash
# Monday morning - need to test something
./scripts/constellation-up.sh
# ☕ Wait 15 minutes

# Work for 3 hours
# Access services via Tailscale at https://webui.yourdomain.com

# Done for the day
./scripts/constellation-down.sh
# Cost for session: 3 hours × $0.25 = $0.75

# Weekend project - 8 hours Saturday
./scripts/constellation-up.sh
# Work all day
./scripts/constellation-down.sh
# Cost: 8 hours × $0.25 = $2.00

# Monthly total: ~$10-15 depending on usage
```

---

## 🎓 Learning Resources

**Terraform**:
- [AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)

**Kubernetes**:
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [External Secrets Operator](https://external-secrets.io/)

**Security**:
- [Tailscale Subnet Routers](https://tailscale.com/kb/1019/subnets/)
- [Authelia Documentation](https://www.authelia.com/)
- [WebAuthn Guide](https://webauthn.guide/)

---

## 🤝 Contributing

This is a personal portfolio project, but feel free to:
- Open issues for questions
- Suggest improvements
- Fork for your own use

---

## 📄 License

MIT License - See LICENSE file for details

---

## 🌟 Acknowledgments

Inspired by:
- **Carian Observatory** (original Docker Compose version)
- **Elden Ring** (naming theme - Caria Manor)
- **Zero Trust principles** from enterprise experience
- **Cloud Native best practices**
