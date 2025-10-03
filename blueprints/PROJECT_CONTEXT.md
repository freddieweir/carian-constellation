# 🌌 Carian Constellation - Project Context

**Last Updated**: 2025-01-02
**Status**: Foundation Phase - Checkpoint 1 Complete
**For**: Future Claude Agents & Continuity

---

## 🎯 Project Overview

**Carian Constellation** is an AWS EKS-based platform replicating the Docker Compose "Carian Observatory" project, demonstrating enterprise-grade SRE practices with Zero Trust security.

### Core Objectives

1. **Showcase SRE Skills**: Demonstrate IaC, Kubernetes, security, and cost optimization
2. **AWS EKS Expertise**: Full production-grade EKS deployment with proper patterns
3. **Cost Optimization**: Ephemeral infrastructure model ($9-15/month vs $110/month always-on)
4. **Zero Trust Security**: Multi-layer defense with hardware MFA (YubiKey)
5. **Resume Portfolio**: Production patterns that translate to enterprise environments

---

## 🏗️ Architecture Decisions

### 1. Ephemeral Infrastructure Pattern

**Decision**: Destroy entire cluster when not in use
**Rationale**: EKS control plane costs $73/month fixed - avoid by destroying everything
**Implementation**: Single command spin-up/down with S3 backup/restore

```
Ephemeral (destroy when done):
├── EKS Cluster
├── EC2 Nodes
├── VPC & Networking
├── ALB
└── NAT Gateway

Persistent (always exist):
├── S3 Buckets (backups, Terraform state)
├── Route53 Hosted Zone
├── Secrets Manager
└── EBS Snapshots
```

**Cost Impact**:
- Always-on: $110-145/month
- Ephemeral (40 hours/month): $15-20/month
- Ephemeral (16 hours/month): $9-12/month

### 2. Security Model: Zero Trust

**Background**: User worked in Zero Trust business unit - this is familiar territory

**Security Layers**:

1. **Network Layer**: Tailscale Zero Trust VPN
   - Only authorized devices can access
   - Private EKS endpoints (no public access)
   - Subnet routing through dedicated relay
   
2. **Infrastructure Layer**: AWS IAM + MFA
   - Mandatory MFA for all AWS operations
   - Client certificates for kubectl
   - Temporary credentials via aws-vault
   
3. **Application Layer**: Authelia + YubiKey
   - WebAuthn/FIDO2 hardware authentication
   - No password-only access
   - Per-service authorization
   
4. **Service Layer**: Kubernetes RBAC
   - Least privilege principle
   - Certificate-based auth
   - Audit logging enabled

### 3. Tagging Strategy

**Comprehensive AWS resource tagging** for cost allocation, automation, and organization:

```
Standard Tags (ALL resources):
- Owner: stalheim
- Project: CarianConstellation
- Environment: personal
- Lifecycle: ephemeral
- ManagedBy: Terraform
- CostCenter: personal-projects
- SecurityZone: restricted
- BackupPolicy: daily-to-s3
```

### 4. Technology Stack

**Infrastructure**:
- AWS EKS 1.28
- Terraform (IaC)
- 2x t3.small nodes (right-sized)
- 1x t3.micro Tailscale relay
- Single NAT Gateway (cost optimization)

**Security**:
- Tailscale (Zero Trust networking)
- Authelia (application auth)
- YubiKey (hardware MFA)
- AWS Secrets Manager + External Secrets Operator
- KMS encryption (EBS, EKS secrets)

**Services** (from Carian Observatory):
- Open-WebUI (AI chat interface)
- Perplexica (AI search)
- Authelia (authentication)
- Homepage (dashboard)
- Glance (monitoring dashboard)
- PGLA stack (Prometheus, Grafana, Loki, Alertmanager)

**Networking**:
- Private subnets for EKS
- Public subnets for Tailscale relay + NAT
- Internal ALB (not internet-facing)
- All traffic through Tailscale

---

## 📁 Project Structure

```
carian-constellation/
├── PROJECT_CONTEXT.md          # THIS FILE - full context for continuity
├── README.md                   # User-facing documentation
├── DEPLOYMENT_GUIDE.md         # Step-by-step deployment instructions
│
├── terraform/
│   ├── bootstrap/              # One-time persistent resources
│   │   ├── main.tf             # S3, DynamoDB, Route53, Secrets Manager
│   │   └── outputs.tf
│   │
│   ├── ephemeral/              # Spin up/down resources
│   │   ├── main.tf
│   │   ├── networking.tf       # VPC, subnets, NAT, Tailscale relay
│   │   ├── eks-cluster.tf      # EKS with private endpoints
│   │   ├── eks-nodes.tf
│   │   ├── security.tf         # Security groups, KMS, IAM
│   │   ├── load-balancer.tf    # Internal ALB configuration
│   │   ├── locals.tf           # Tagging standards
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── templates/
│   │       └── tailscale-relay.sh
│   │
│   └── modules/                # Reusable Terraform modules
│       ├── vpc/
│       ├── eks/
│       └── security/
│
├── kubernetes/
│   ├── manifests/              # Direct YAML deployments
│   │   ├── 00-namespaces/
│   │   ├── 01-external-secrets/
│   │   ├── 02-ingress/
│   │   ├── 03-cert-manager/
│   │   ├── 10-auth/            # Authelia with WebAuthn
│   │   ├── 20-ai-services/     # Open-WebUI, Perplexica
│   │   ├── 30-platform/        # Homepage, Glance
│   │   └── 40-monitoring/      # PGLA stack
│   │
│   └── helm-values/            # Helm chart configurations
│       ├── aws-load-balancer-controller.yaml
│       ├── external-secrets.yaml
│       └── prometheus-stack-minimal.yaml
│
├── scripts/
│   ├── constellation-up.sh     # ONE COMMAND: Spin up everything
│   ├── constellation-down.sh   # ONE COMMAND: Destroy everything
│   ├── constellation-status.sh # Check if running
│   ├── backup-data.sh          # Backup to S3 before destroy
│   ├── restore-data.sh         # Restore from S3 after create
│   ├── cost-tracker.sh         # Track spending
│   │
│   └── security/
│       ├── setup-tailscale.sh
│       ├── generate-kubectl-certs.sh
│       └── configure-yubikey.sh
│
└── docs/
    ├── architecture.md         # Detailed architecture diagrams
    ├── security-model.md       # Security implementation details
    ├── cost-optimization.md    # Cost breakdown and strategies
    ├── tagging-strategy.md     # AWS tagging standards
    └── troubleshooting.md      # Common issues and solutions
```

---

## 🚀 Deployment Workflow

### Phase 1: Bootstrap (One-Time)
```bash
cd terraform/bootstrap
terraform init
terraform apply
# Creates: S3, DynamoDB, Route53, Secrets Manager
```

### Phase 2: Ephemeral Spin-Up
```bash
./scripts/constellation-up.sh
# 12-18 minutes total:
# 1. Deploy VPC, EKS, nodes, Tailscale relay
# 2. Configure kubectl
# 3. Install controllers (ALB, External Secrets, cert-manager)
# 4. Restore data from S3
# 5. Deploy services
```

### Phase 3: Use Your Constellation
```
Access via Tailscale:
- https://webui.yourdomain.com (Open-WebUI)
- https://perplexica.yourdomain.com (Search)
- https://auth.yourdomain.com (Authelia)
- https://monitoring.yourdomain.com (Grafana)

All require YubiKey tap for access
```

### Phase 4: Tear Down
```bash
./scripts/constellation-down.sh
# 5-8 minutes:
# 1. Backup all data to S3
# 2. Clean up Kubernetes resources
# 3. Destroy AWS infrastructure (terraform destroy)
# 4. Cost: $0.00/hour (only S3 storage remains)
```

---

## 💰 Cost Model

**Hourly Rate While Running**: $0.25/hour
```
- EKS Control Plane: $0.10/hour
- 2x t3.small nodes: $0.042/hour
- 1x t3.micro Tailscale: $0.0052/hour
- Internal ALB: $0.0225/hour
- NAT Gateway: $0.045/hour
- Data transfer: ~$0.01/hour
```

**Persistent Costs**: ~$5.50/month
```
- S3 (backups, state): $1/month
- Route53 zone: $0.50/month
- Secrets Manager: $1/month
- KMS keys (2): $2/month
- EBS snapshots: $1/month
```

**Usage Examples**:
- Weekend projects (16 hrs/month): $9.50/month
- Regular use (40 hrs/month): $15.50/month
- Heavy use (100 hrs/month): $30.50/month

---

## 🔒 Security Implementation Details

### Tailscale Zero Trust Network

**Why Tailscale over alternatives**:
- Free for personal use
- Zero Trust architecture (BeyondCorp model)
- Encrypted mesh network (WireGuard)
- No VPN concentrator needed
- Easy device management

**Implementation**:
1. Tailscale relay node in AWS (t3.micro)
2. Advertises VPC CIDR as routes
3. EKS has private endpoint only
4. All access through Tailscale tunnel

### YubiKey WebAuthn

**Why YubiKey**:
- Hardware-based authentication (phishing-resistant)
- Industry standard (FIDO2/WebAuthn)
- No passwords stored anywhere
- User already owns YubiKey from previous work

**Implementation**:
1. Authelia configured for WebAuthn
2. YubiKey registered as 2FA device
3. Every service access requires tap
4. No fallback to password-only

### AWS IAM Security

**Mandatory MFA Policy**:
- All AWS actions require active MFA session
- Enforced via IAM policy (DenyAllIfNoMFA)
- Temporary credentials via aws-vault
- No long-lived access keys in use

### Kubernetes RBAC

**Certificate-based authentication**:
- Client certificates for kubectl access
- User belongs to `constellation-admins` group
- ClusterRoleBinding for full access
- All actions logged for audit

---

## 📊 Key Metrics

**Spin-up Time**: 12-18 minutes
**Tear-down Time**: 5-8 minutes
**Data Backup Time**: 2-3 minutes
**Data Restore Time**: 3-5 minutes

**Security Layers**: 4 (Network, Infrastructure, Application, Service)
**Encryption**: All data (in-transit TLS, at-rest KMS)
**Cost Reduction**: 85-90% vs always-on

---

## 🎓 Skills Demonstrated

### Infrastructure as Code
- ✅ Terraform multi-environment setup
- ✅ Modular, reusable infrastructure
- ✅ Remote state management (S3 + DynamoDB)
- ✅ Comprehensive tagging strategy

### Kubernetes Expertise
- ✅ Production EKS deployment
- ✅ IRSA (IAM Roles for Service Accounts)
- ✅ External Secrets Operator integration
- ✅ Ingress and service mesh patterns
- ✅ Resource right-sizing

### Zero Trust Security
- ✅ Network segmentation (Tailscale)
- ✅ Hardware MFA (YubiKey WebAuthn)
- ✅ Certificate-based authentication
- ✅ Encryption everywhere
- ✅ Least privilege access

### Cost Optimization
- ✅ Ephemeral infrastructure pattern
- ✅ Right-sized instances
- ✅ Single NAT gateway
- ✅ Cost tracking and monitoring
- ✅ Pay-per-use model

### Site Reliability Engineering
- ✅ Automated backup/restore
- ✅ Reproducible environments
- ✅ Comprehensive monitoring (PGLA)
- ✅ Audit logging
- ✅ Disaster recovery procedures

---

## 🔄 Current Status

**Phase**: Foundation Setup (Checkpoint 1)
**Completed**:
- ✅ Architecture design
- ✅ Security model definition
- ✅ Cost optimization strategy
- ✅ Directory structure created
- ✅ Context documentation (this file)

**Next Steps**:
1. Create Terraform bootstrap module
2. Create Terraform ephemeral module
3. Create Kubernetes manifests
4. Create automation scripts
5. Create documentation

**Checkpoint System**: Work in small increments to avoid timeouts

---

## 📝 Notes for Future Claude Agents

### Critical Context

1. **User Background**: Worked in Zero Trust business unit - very familiar with the concepts
2. **Cost Sensitivity**: Budget is $10-15/month, not $100+/month
3. **Security Focus**: Multi-layer defense, hardware MFA, no shortcuts
4. **Real-World Patterns**: This must demonstrate enterprise practices
5. **Portfolio Purpose**: For SRE job applications and interviews

### Technical Requirements

- **AWS Region**: us-east-1 (cheapest)
- **Domain**: User will provide their actual domain
- **YubiKey**: User already owns and uses YubiKey
- **Tailscale**: Free tier is sufficient
- **Spot Instances**: Can consider for extra savings

### Important Patterns

1. **Always use comprehensive tags** on ALL AWS resources
2. **Never expose services publicly** - always through Tailscale
3. **No hardcoded secrets** - use Secrets Manager + External Secrets
4. **Single NAT gateway** - cost optimization
5. **Private EKS endpoints** - security requirement
6. **Backup before destroy** - data preservation critical

### Communication Style

- User appreciates technical depth
- Prefers production-grade solutions over shortcuts
- Values cost optimization but not at expense of security
- Wants resume/interview talking points embedded in implementation

---

## 🚨 Known Issues & Workarounds

### Issue 1: Long Response Timeouts
**Problem**: Very long responses cause conversation reversion
**Solution**: Work in checkpoints, wait for user confirmation

### Issue 2: Tailscale Setup Complexity
**Solution**: Detailed step-by-step guides with screenshots in docs/

### Issue 3: EKS Cold Start Time
**Problem**: 12-18 minutes feels long
**Mitigation**: This is normal for EKS, optimize what we can

---

## 📚 Reference Links

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Tailscale Subnet Routers](https://tailscale.com/kb/1019/subnets/)
- [Authelia Documentation](https://www.authelia.com/configuration/prologue/introduction/)
- [External Secrets Operator](https://external-secrets.io/)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)

---

**End of Context Document**
**Next Claude Agent**: Please read this entire file before proceeding with any implementation.
