# 🌌 Carian Constellation

**Transforming [Carian Observatory](../carian-observatory) from Docker Compose to AWS EKS**

[![Infrastructure](https://img.shields.io/badge/Infrastructure-AWS%20EKS-orange)](https://aws.amazon.com/eks/)
[![Security](https://img.shields.io/badge/Security-Zero%20Trust-green)](https://www.cloudflare.com/learning/security/glossary/what-is-zero-trust/)
[![IaC](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)
[![Target Cost](https://img.shields.io/badge/Target_Cost-$10--15%2Fmonth-blue)](#cost-optimization-strategy)
[![Status](https://img.shields.io/badge/Status-Proposal_Phase-yellow)](#project-timeline)

---

## 📖 What Is This?

Carian Constellation is an **AWS EKS migration** of the Carian Observatory platform, implementing SRE best practices with Zero Trust security and ephemeral infrastructure.

### The Challenge

Carian Observatory works perfectly for local-only use, but I wanted to push beyond that - to build something that **challenges me more with all of my acquired knowledge**. Moving from Docker Compose to EKS means:
- Managing a cloud Kubernetes cluster at scale (beyond the usual k8s work typically done for work)
- Implementing deep AWS service integration (IRSA, Secrets Manager, ALB)
- Building Zero Trust security that works remotely
- Keeping costs under control with ephemeral infrastructure
- Making it all reproducible and automated

### The Solution

Deploy the same platform to AWS EKS with **85% cost reduction** through ephemeral infrastructure, using patterns from modern cloud architectures.

| Metric | Carian Observatory | Always-On EKS | **Carian Constellation** |
|--------|-------------------|---------------|------------------------|
| **Platform** | Docker Compose | AWS EKS | AWS EKS (Ephemeral) |
| **Monthly Cost** | $0 (local) | $110-145 | **$10-15** |
| **Infrastructure** | Single Docker host | Fixed cluster | Spin up/down on demand |
| **Security Model** | Authelia only | Standard K8s RBAC | **Zero Trust (4 layers)** |

---

## 🎯 Project Goals

### Primary Objectives

1. **Refresh EKS Skills**: Deploy and manage a real EKS cluster with modern AWS service integration
2. **Master Cost Optimization**: Achieve 85% cost reduction through ephemeral infrastructure patterns
3. **Implement Zero Trust Security**: Multi-layer architecture with hardware MFA (YubiKey)
4. **Practice SRE Workflows**: Backup/restore, monitoring, IaC, automation, disaster recovery
5. **Push Technical Boundaries**: Build something more challenging than "just make it work"

### Success Criteria

- ✅ All Carian Constellation services running on EKS
- ✅ Monthly cost under $15 with regular weekend usage
- ✅ Infrastructure spins up in under 20 minutes
- ✅ Infrastructure tears down in under 10 minutes with data preservation
- ✅ Zero Trust security with hardware MFA (YubiKey)
- ✅ Complete automation (one-command deploy/destroy)
- ✅ Production monitoring (Prometheus, Grafana, Loki)

---

<details>
<summary><strong>🏗️ Architecture Overview</strong></summary>

## System Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Your Workstation                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │  YubiKey     │  │  aws-vault   │  │  Tailscale Client        │  │
│  │  (Hardware   │  │  (AWS MFA)   │  │  (Zero Trust VPN)        │  │
│  │   Security)  │  │              │  │                          │  │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                    Tailscale VPN Tunnel
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (us-east-1)                        │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    VPC: 10.0.0.0/16                           │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │  Public Subnets (10.0.1.0/24, 10.0.2.0/24)              │  │  │
│  │  │  ┌───────────────┐  ┌───────────────────────────────┐  │  │  │
│  │  │  │ NAT Gateway   │  │ Tailscale Relay (t3.micro)    │  │  │  │
│  │  │  │ (Single AZ)   │  │ - Advertises VPC routes        │  │  │  │
│  │  │  └───────────────┘  │ - Zero Trust VPN endpoint      │  │  │  │
│  │  │                     └───────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  │                                                                 │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │  Private Subnets (10.0.10.0/24, 10.0.11.0/24)          │  │  │
│  │  │  ┌─────────────────────────────────────────────────┐   │  │  │
│  │  │  │        EKS Cluster (Private Endpoint Only)      │   │  │  │
│  │  │  │  ┌──────────────────────────────────────────┐   │   │  │  │
│  │  │  │  │   Worker Nodes (2x t3.small)             │   │   │  │  │
│  │  │  │  │                                          │   │   │  │  │
│  │  │  │  │  ┌────────────────────────────────┐    │   │   │  │  │
│  │  │  │  │  │  Namespace: carian-apps        │    │   │   │  │  │
│  │  │  │  │  │  - Open-WebUI (AI Chat)        │    │   │   │  │  │
│  │  │  │  │  │  - Perplexica (AI Search)      │    │   │   │  │  │
│  │  │  │  │  │  - Authelia (Auth Gateway)     │    │   │   │  │  │
│  │  │  │  │  └────────────────────────────────┘    │   │   │  │  │
│  │  │  │  │                                          │   │   │  │  │
│  │  │  │  │  ┌────────────────────────────────┐    │   │   │  │  │
│  │  │  │  │  │  Namespace: carian-data        │    │   │   │  │  │
│  │  │  │  │  │  - PostgreSQL (Database)       │    │   │   │  │  │
│  │  │  │  │  │  - EBS Volumes (Persistent)    │    │   │   │  │  │
│  │  │  │  │  └────────────────────────────────┘    │   │   │  │  │
│  │  │  │  │                                          │   │   │  │  │
│  │  │  │  │  ┌────────────────────────────────┐    │   │   │  │  │
│  │  │  │  │  │  Namespace: carian-monitoring  │    │   │   │  │  │
│  │  │  │  │  │  - Prometheus (Metrics)        │    │   │   │  │  │
│  │  │  │  │  │  - Grafana (Visualization)     │    │   │   │  │  │
│  │  │  │  │  │  - Loki (Logs)                 │    │   │   │  │  │
│  │  │  │  │  │  - Alertmanager (Alerts)       │    │   │   │  │  │
│  │  │  │  │  └────────────────────────────────┘    │   │   │  │  │
│  │  │  │  │                                          │   │   │  │  │
│  │  │  │  │  ┌────────────────────────────────┐    │   │   │  │  │
│  │  │  │  │  │  Controllers                   │    │   │   │  │  │
│  │  │  │  │  │  - AWS Load Balancer (IRSA)    │    │   │   │  │  │
│  │  │  │  │  │  - External Secrets (IRSA)     │    │   │   │  │  │
│  │  │  │  │  │  - cert-manager (TLS)          │    │   │   │  │  │
│  │  │  │  │  │  - EBS CSI Driver (IRSA)       │    │   │   │  │  │
│  │  │  │  │  └────────────────────────────────┘    │   │   │  │  │
│  │  │  │  └──────────────────────────────────────┘   │   │  │  │
│  │  │  │                                               │   │  │  │
│  │  │  │  ┌──────────────────────────────────────┐   │   │  │  │
│  │  │  │  │  Internal ALB (Private)              │   │   │  │  │
│  │  │  │  │  - Routes to services via ingress    │   │   │  │  │
│  │  │  │  └──────────────────────────────────────┘   │   │  │  │
│  │  │  └─────────────────────────────────────────────┘   │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              Persistent Resources (Always Exist)              │  │
│  │  - S3 Buckets (Terraform state, data backups)                 │  │
│  │  - Route53 Hosted Zone (freddieweir.com)                        │  │
│  │  - AWS Secrets Manager (API keys, certificates)               │  │
│  │  - DynamoDB (Terraform state locking)                         │  │
│  │  - KMS Keys (Encryption)                                      │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Three-Layer Terraform Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Layer 1: Bootstrap                           │
│                   (One-Time Setup)                              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Lifecycle: Permanent (never destroyed)                    │  │
│  │ Backend: Local (creates S3 backend)                       │  │
│  │ Cost: ~$5.50/month                                        │  │
│  │                                                           │  │
│  │ Resources:                                                │  │
│  │  • S3 bucket (Terraform remote state)                    │  │
│  │  • DynamoDB table (state locking)                        │  │
│  │  • Route53 hosted zone                                   │  │
│  │  • AWS Secrets Manager                                   │  │
│  │  • IAM policies and roles                                │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Layer 2: Ephemeral                           │
│                  (Spin Up/Down on Demand)                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Lifecycle: Ephemeral (destroyed when not in use)          │  │
│  │ Backend: S3 (configured via backend.hcl)                  │  │
│  │ Cost: $0.25/hour when running                             │  │
│  │                                                           │  │
│  │ Resources:                                                │  │
│  │  • EKS cluster + control plane                           │  │
│  │  • VPC (public/private subnets)                          │  │
│  │  • NAT gateway (single AZ)                               │  │
│  │  • EC2 worker nodes (2x t3.small)                        │  │
│  │  • Tailscale relay (t3.micro)                            │  │
│  │  • Security groups + KMS keys                            │  │
│  │  • Internal ALB                                          │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Layer 3: Persistent                           │
│                  (Kubernetes Controllers)                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Lifecycle: Deployed after cluster, destroyed before       │  │
│  │ Backend: S3 (configured via backend.hcl)                  │  │
│  │ Cost: Included in ephemeral cluster cost                  │  │
│  │                                                           │  │
│  │ Resources (Helm charts):                                  │  │
│  │  • AWS Load Balancer Controller                          │  │
│  │  • External Secrets Operator                             │  │
│  │  • cert-manager (TLS automation)                         │  │
│  │  • kube-prometheus-stack                                 │  │
│  │  • EBS CSI driver                                        │  │
│  │  • IRSA roles for all controllers                       │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
                   ┌─────────────────────┐
                   │ Kubernetes Manifests│
                   │ (kubectl apply)     │
                   └─────────────────────┘
```

### Security Architecture (Zero Trust - 4 Layers)

```
┌──────────────────────────────────────────────────────────────────┐
│                     Layer 4: Service Layer                       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ Kubernetes RBAC                                            │  │
│  │  • Certificate-based authentication for kubectl           │  │
│  │  • Least privilege service accounts                       │  │
│  │  • Pod Security Standards (baseline/restricted)           │  │
│  │  • Network Policies (namespace isolation)                 │  │
│  │  • Audit logging enabled                                  │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                   Layer 3: Application Layer                     │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ Authelia with YubiKey WebAuthn                             │  │
│  │  • Hardware FIDO2/U2F authentication required             │  │
│  │  • No password-only access allowed                        │  │
│  │  • Physical tap required for every login                  │  │
│  │  • Per-service authorization rules                        │  │
│  │  • Session management in Redis                            │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                 Layer 2: Infrastructure Layer                    │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ AWS IAM with Mandatory MFA                                 │  │
│  │  • All AWS operations require active MFA session          │  │
│  │  • Temporary credentials via aws-vault                    │  │
│  │  • Client certificates for kubectl access                 │  │
│  │  • IRSA for service accounts (no static credentials)      │  │
│  │  • KMS encryption for all data at rest                    │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Layer 1: Network Layer                        │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ Tailscale Zero Trust VPN                                   │  │
│  │  • Private EKS endpoints only (no public access)           │  │
│  │  • Subnet routing through dedicated relay node            │  │
│  │  • Device authentication required (BeyondCorp model)       │  │
│  │  • WireGuard encrypted mesh network                       │  │
│  │  • All access requires Tailscale authentication           │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

</details>

---

<details>
<summary><strong>💰 Cost Optimization Strategy</strong></summary>

## Cost Breakdown

### Target: $10-15/month with Regular Usage

#### Persistent Costs (Always Running)
```
S3 Bucket (Terraform state)         $1.00/month
S3 Bucket (Data backups)            $1.00/month
Route53 Hosted Zone                 $0.50/month
AWS Secrets Manager (5 secrets)     $2.00/month
KMS Keys (2)                        $2.00/month
DynamoDB (state locking)            $0.00/month (free tier)
                                    ─────────────
Total Persistent:                   $6.50/month
```

#### Ephemeral Costs (Only When Running)
```
Hourly Breakdown:
EKS Control Plane                   $0.10/hour
2x t3.small nodes (on-demand)       $0.0416/hour × 2 = $0.0832/hour
1x t3.micro Tailscale relay         $0.0104/hour
Internal ALB                        $0.0225/hour
NAT Gateway (single AZ)             $0.045/hour
Data transfer (estimate)            $0.01/hour
                                    ──────────────
Hourly Total:                       $0.2711/hour (~$0.27/hour)
```

### Cost by Usage Pattern

| Usage Pattern | Hours/Month | Ephemeral Cost | Total/Month |
|---------------|-------------|----------------|-------------|
| **Weekend Projects** | 16 hours (8hrs × 2 days) | $4.34 | **$10.84** |
| **Light Use** | 24 hours (6hrs × 4 days) | $6.50 | **$13.00** |
| **Regular Use** | 40 hours (10hrs × 4 days) | $10.84 | **$17.34** |
| **Heavy Use** | 80 hours (20hrs × 4 days) | $21.69 | **$28.19** |
| **Always-On** | 720 hours (24/7) | $195.19 | **$201.69** |

### Comparison to Always-On EKS

| Component | Always-On | Ephemeral (40hrs) | **Savings** |
|-----------|-----------|-------------------|-------------|
| EKS Control Plane | $73.00 | $4.00 | **95% reduction** |
| Worker Nodes | $59.90 | $3.33 | **94% reduction** |
| Tailscale Relay | $7.49 | $0.42 | **94% reduction** |
| NAT Gateway | $32.40 | $1.80 | **94% reduction** |
| ALB | $16.20 | $0.90 | **94% reduction** |
| Infrastructure Total | $188.99 | $10.45 | **95% reduction** |
| **With Persistent** | **$195.49** | **$16.95** | **91% reduction** |

### Cost Optimization Techniques

**Ephemeral Infrastructure**:
- Destroy cluster when not in use ($0/hour when destroyed)
- Automated backup to S3 before destruction
- Automated restore from S3 after creation
- Spin-up time: 12-18 minutes
- Tear-down time: 5-8 minutes

**Right-Sized Instances**:
- t3.small nodes (2 vCPU, 2 GiB) for AI workloads
- t3.micro relay (1 vCPU, 1 GiB) for Tailscale
- Burst performance for occasional spikes

**Single NAT Gateway**:
- One NAT gateway instead of multi-AZ ($32.40/month savings per extra NAT)
- Acceptable for non-production workload
- VPC endpoints for AWS services (avoid NAT costs)

**Future Optimizations** (not implemented yet):
- SPOT instances for 60-70% additional savings (~$7/month total)
- Fargate Spot for 70% savings on compute
- Reserved instances if usage increases

### Typical Monthly Scenarios

**Example 1: Weekend Hobbyist**
```
Usage: Saturday and Sunday, 8 hours each (16 hours/month)
Ephemeral: 16 × $0.27 = $4.32
Persistent: $6.50
Total: $10.82/month ✅
```

**Example 2: Side Project Developer**
```
Usage: 4 weekends, 10 hours each (40 hours/month)
Ephemeral: 40 × $0.27 = $10.80
Persistent: $6.50
Total: $17.30/month ⚠️ (slightly over target)
```

**Example 3: Interview Preparation**
```
Usage: 2 hours daily for demos (60 hours/month)
Ephemeral: 60 × $0.27 = $16.20
Persistent: $6.50
Total: $22.70/month ⚠️ (over budget, consider SPOT)
```

</details>

---

<details>
<summary><strong>🔒 Security Model</strong></summary>

## Zero Trust Security Architecture

### Design Philosophy

Based on **Cisco's Zero Trust** architecture principles:

1. **Never trust, always verify** - Every access attempt requires authentication
2. **Least privilege** - Minimum permissions required for each component
3. **Defense in depth** - Multiple security layers (network, infrastructure, application, service)
4. **Hardware security** - Physical MFA tokens (YubiKey) for authentication
5. **No implicit trust** - Private networks don't mean trusted access

### Security Layer Breakdown

#### Layer 1: Network Security (Tailscale Zero Trust VPN)

**Why Tailscale over traditional VPN**:
- Zero Trust architecture (not perimeter-based)
- Free for personal use (vs $5-10/month for alternatives)
- WireGuard protocol (modern, fast, secure)
- No VPN concentrator needed (mesh network)
- Device-based authentication (not just user-based)
- Easy client management (web console)

**Implementation**:
```
Your Laptop (Tailscale client)
       │
       ├─ Authentication required to join network
       ├─ Device must be explicitly authorized
       │
       └──> Tailscale Relay Node (t3.micro in AWS)
                 │
                 ├─ Advertises VPC CIDR (10.0.0.0/16) as routes
                 ├─ Forwards traffic to private subnets
                 │
                 └──> EKS Private Endpoint (10.0.10.x)
                        │
                        └──> Only accessible via Tailscale tunnel
```

**Benefits**:
- EKS has **private endpoint only** (no public access)
- Cannot access cluster without Tailscale authentication
- All traffic encrypted end-to-end (WireGuard)
- No exposed security groups or firewall rules

#### Layer 2: Infrastructure Security (AWS IAM + MFA)

**Mandatory MFA Policy**:
```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "BoolIfExists": {"aws:MultiFactorAuthPresent": "false"}
  }
}
```

**Implementation**:
- All AWS operations require active MFA session
- Use `aws-vault` for temporary credentials with MFA
- No long-lived access keys in use
- MFA session expires after 12 hours (re-authenticate)

**kubectl Access**:
- Client certificates for authentication (not passwords)
- User belongs to `constellation-admins` Kubernetes group
- ClusterRoleBinding grants cluster-admin permissions
- All kubectl operations logged for audit

**IRSA (IAM Roles for Service Accounts)**:
- Controllers use IRSA instead of static credentials
- ALB Controller has EC2/ELB permissions via IRSA
- External Secrets Operator has Secrets Manager access via IRSA
- EBS CSI driver has EC2 volume permissions via IRSA
- Trust relationship with EKS OIDC provider

#### Layer 3: Application Security (Authelia + YubiKey WebAuthn)

**Why YubiKey over TOTP**:
- Hardware-based authentication (phishing-resistant)
- Industry standard (FIDO2/WebAuthn)
- No passwords stored anywhere
- Physical tap required (cannot be remotely exploited)
- Already have one from previous projects

**Authentication Flow**:
```
1. User requests service (https://webui.cc.freddieweir.com)
2. ALB Ingress forwards to service
3. Service requires authentication
4. Redirect to Authelia (https://auth.cc.freddieweir.com)
5. User authenticates:
   - Username
   - Password
   - YubiKey tap (WebAuthn/FIDO2)
6. Session stored in Redis (encrypted)
7. Cookie issued, forwarded to requested service
```

**Access Control**:
```yaml
# Default policy: deny (explicit allow required)
access_control:
  default_policy: 'deny'

  rules:
    - domain: 'webui.cc.freddieweir.com'
      policy: 'two_factor'

    - domain: 'perplexica.cc.freddieweir.com'
      policy: 'two_factor'

    - domain: 'monitoring.cc.freddieweir.com'
      policy: 'two_factor'
```

**Session Management**:
- Sessions stored in Redis (ephemeral, encrypted)
- Session timeout: 1 hour inactivity
- Remember me: 30 days (requires re-authentication)
- No session sharing between services

#### Layer 4: Service Security (Kubernetes RBAC)

**Certificate-Based Authentication**:
```bash
# kubectl access via client certificates
aws eks update-kubeconfig --name constellation-dev
# Creates kubeconfig with:
#  - Client certificate
#  - Certificate authority data
#  - Cluster endpoint (via Tailscale)
```

**Namespace Isolation**:
- `carian-apps`: Main applications (NetworkPolicies)
- `carian-data`: Database layer (isolated from apps)
- `carian-monitoring`: Observability stack (privileged)
- Each namespace has resource quotas (CPU, memory limits)

**Pod Security Standards**:
```yaml
# carian-apps namespace
pod-security.kubernetes.io/enforce: baseline
pod-security.kubernetes.io/audit: restricted
pod-security.kubernetes.io/warn: restricted

# Prevents:
#  - Privilege escalation
#  - Host namespace access
#  - Running as root (where possible)
```

**Service Account Permissions**:
- Least privilege principle for all service accounts
- IRSA for AWS service integration (no static credentials)
- Role-based access control for inter-service communication

### Data Protection

**Encryption at Rest**:
- EBS volumes encrypted with KMS
- EKS secrets encrypted with KMS
- S3 backups encrypted with SSE-KMS
- Secrets Manager uses KMS encryption

**Encryption in Transit**:
- TLS for all external traffic (cert-manager)
- Service-to-service communication over internal network
- Tailscale encrypts all VPN traffic (WireGuard)

**Secrets Management**:
- AWS Secrets Manager for API keys, certificates
- External Secrets Operator syncs to Kubernetes Secrets
- No hardcoded secrets in code or manifests
- 1Password integration for local development (optional)

### Security Monitoring

**Audit Logging**:
- EKS control plane logs to CloudWatch
- kubectl commands audited
- AWS API calls logged via CloudTrail

**Intrusion Detection** (future):
- Falco for runtime security
- AWS GuardDuty for threat detection

</details>

---

<details>
<summary><strong>📊 Services & Components</strong></summary>

## Service Migration Plan

All services from Carian Observatory will be migrated to Kubernetes:

### AI Services (Namespace: `carian-apps`)

| Service | Docker | Kubernetes | Notes |
|---------|--------|------------|-------|
| **Open-WebUI** | ✅ Running (OpenRouter) | 📋 Planned | AI chat interface with Amazon Bedrock |
| **Perplexica** | ✅ Running | 📋 Planned | AI-powered search engine |
| **SearXNG** | ✅ Running | 📋 Planned | Meta-search backend for Perplexica |

### Platform Services (Namespace: `carian-apps`)

| Service | Docker | Kubernetes | Notes |
|---------|--------|------------|-------|
| **Authelia** | ✅ Running | 📋 Planned | Authentication gateway with WebAuthn |
| **Homepage** | ✅ Running | 📋 Planned | Unified platform dashboard |
| **Glance** | ✅ Running | 📋 Planned | RSS feed monitoring dashboard |

### Data Layer (Namespace: `carian-data`)

| Service | Docker | Kubernetes | Notes |
|---------|--------|------------|-------|
| **PostgreSQL** | 🚧 Development | 📋 Planned | Database for Open-WebUI, Authelia |
| **Redis** | ✅ Running | 📋 Planned | Session storage for Authelia |

### Monitoring Stack (Namespace: `carian-monitoring`)

| Service | Docker | Kubernetes | Notes |
|---------|--------|------------|-------|
| **Prometheus** | ✅ Running | 📋 Planned | Metrics collection |
| **Grafana** | ✅ Running | 📋 Planned | Metrics visualization |
| **Loki** | ✅ Running | 📋 Planned | Log aggregation |
| **Alertmanager** | ✅ Running | 📋 Planned | Alert routing |

### Infrastructure Components

| Component | Purpose | Implementation |
|-----------|---------|----------------|
| **Nginx** | Reverse proxy + SSL | **Replaced by**: AWS ALB + Ingress |
| **Watchtower** | Auto-updates | **Replaced by**: Kubernetes rolling updates |
| **1Password Connect** | Secret management | **Replaced by**: AWS Secrets Manager + External Secrets Operator |

### Kubernetes Controllers (Deployed via Helm)

| Controller | Purpose | IRSA |
|------------|---------|------|
| **AWS Load Balancer Controller** | ALB Ingress for services | ✅ Yes |
| **External Secrets Operator** | Sync AWS Secrets Manager → K8s Secrets | ✅ Yes |
| **cert-manager** | TLS certificate automation | ❌ No |
| **kube-prometheus-stack** | Monitoring (Prometheus, Grafana, Alertmanager) | ❌ No |
| **EBS CSI Driver** | Persistent volume provisioning | ✅ Yes |

</details>

---

<details>
<summary><strong>🚀 Deployment Workflow</strong></summary>

## How It Works

### One-Time Bootstrap (First Setup)

```bash
# Step 1: Bootstrap persistent infrastructure
cd terraform/bootstrap
terraform init
terraform apply

# Creates:
#  - S3 bucket for Terraform state
#  - DynamoDB table for state locking
#  - Route53 hosted zone (freddieweir.com)
#  - AWS Secrets Manager (for API keys)
#  - IAM policies and roles

# This runs ONCE and is never destroyed
```

### Regular Operations (Spin Up Constellation)

```bash
# Step 2: Deploy ephemeral infrastructure
./scripts/constellation-up.sh

# What it does (12-18 minutes):
#  1. Terraform apply (ephemeral module)
#     - Creates VPC, subnets, NAT gateway
#     - Deploys EKS cluster (private endpoint)
#     - Launches 2x t3.small worker nodes
#     - Deploys Tailscale relay node
#
#  2. Terraform apply (persistent module)
#     - Installs AWS Load Balancer Controller (Helm)
#     - Installs External Secrets Operator (Helm)
#     - Installs cert-manager (Helm)
#     - Installs kube-prometheus-stack (Helm)
#     - Installs EBS CSI driver (Helm)
#
#  3. Restore data from S3
#     - Downloads latest backup
#     - Restores PostgreSQL database
#     - Restores Open-WebUI data
#
#  4. Deploy applications (kubectl apply)
#     - Namespaces with quotas
#     - External Secrets (sync from AWS)
#     - Application deployments
#     - Ingress resources (ALB)
#     - ServiceMonitors (Prometheus)

# Result: Full constellation running, accessible via Tailscale
```

### Using Your Constellation

```bash
# Connect to Tailscale VPN
tailscale up

# Access services (requires YubiKey authentication):
#  - https://webui.cc.freddieweir.com       (Open-WebUI)
#  - https://perplexica.cc.freddieweir.com  (AI Search)
#  - https://auth.cc.freddieweir.com        (Authelia)
#  - https://monitoring.cc.freddieweir.com  (Grafana)
#  - https://homepage.cc.freddieweir.com    (Dashboard)

# Check cluster status
kubectl get nodes
kubectl get pods -A
kubectl top nodes
```

### Tearing Down (When Finished)

```bash
# Step 3: Destroy infrastructure (save money)
./scripts/constellation-down.sh

# What it does (5-8 minutes):
#  1. Backup all data to S3
#     - PostgreSQL database dump
#     - Open-WebUI data archive
#     - Configuration backups
#
#  2. Clean up Kubernetes resources
#     - Delete application pods
#     - Remove ingress (ALB cleanup)
#     - Delete persistent volumes
#
#  3. Terraform destroy (persistent module)
#     - Removes Helm chart deployments
#     - Cleans up IRSA roles
#
#  4. Terraform destroy (ephemeral module)
#     - Destroys EKS cluster
#     - Removes worker nodes
#     - Deletes VPC and networking
#     - Terminates Tailscale relay

# Result: $0/hour cost (only persistent S3/Route53 remain)
```

### Workflow Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                     One-Time Bootstrap                         │
│  terraform/bootstrap/                                          │
│  • Creates S3, DynamoDB, Route53, Secrets Manager              │
│  • Run once, never destroyed                                   │
└────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌────────────────────────────────────────────────────────────────┐
│               Spin Up (constellation-up.sh)                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 1. Deploy Ephemeral (12-15 min)                          │  │
│  │    terraform/ephemeral/                                  │  │
│  │    • VPC, EKS, nodes, Tailscale                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                             │                                  │
│                             ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 2. Deploy Controllers (3-5 min)                          │  │
│  │    terraform/persistent/                                 │  │
│  │    • ALB Controller, External Secrets, etc.              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                             │                                  │
│                             ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 3. Restore Data (2-3 min)                                │  │
│  │    scripts/restore-data.sh                               │  │
│  │    • Download from S3                                    │  │
│  │    • Restore databases                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                             │                                  │
│                             ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 4. Deploy Applications (2-3 min)                         │  │
│  │    kubectl apply -f kubernetes/                          │  │
│  │    • Namespaces, secrets, apps, ingress                  │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
                             │
                             ▼
                      ┌─────────────┐
                      │   USE IT!   │
                      │ (Pay by hour)│
                      └─────────────┘
                             │
                             ▼
┌────────────────────────────────────────────────────────────────┐
│             Tear Down (constellation-down.sh)                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 1. Backup Data (2-3 min)                                 │  │
│  │    scripts/backup-data.sh                                │  │
│  │    • Upload to S3                                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                             │                                  │
│                             ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 2. Destroy Controllers (2 min)                           │  │
│  │    terraform destroy (persistent)                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                             │                                  │
│                             ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ 3. Destroy Infrastructure (3-5 min)                      │  │
│  │    terraform destroy (ephemeral)                         │  │
│  │    • EKS, VPC, nodes deleted                             │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
                             │
                             ▼
                      ┌─────────────┐
                      │ $0/hour cost│
                      │ (S3 remains)│
                      └─────────────┘
```

</details>

---

<details>
<summary><strong>🎯 Technical Skills</strong></summary>

## What This Project Covers

### Infrastructure as Code (Terraform)
- Multi-environment Terraform architecture (bootstrap → ephemeral → persistent)
- Remote state management (S3 + DynamoDB locking)
- Terraform modules for reusability
- Partial backend configuration patterns
- Comprehensive resource tagging strategy
- Provider dependency management (Kubernetes provider after EKS)

### Kubernetes on AWS
- EKS deployment with private endpoints
- IRSA (IAM Roles for Service Accounts) for AWS integration
- External Secrets Operator for secret management
- ALB Ingress controller with proper annotations
- Namespace isolation with resource quotas
- Pod Security Standards (baseline/restricted)
- NetworkPolicies for service isolation
- Helm chart deployments for controllers

### Zero Trust Security
- Four-layer security model (network, infrastructure, application, service)
- Hardware MFA (YubiKey WebAuthn/FIDO2)
- Private infrastructure (Tailscale VPN for all access)
- Certificate-based authentication (kubectl)
- Mandatory AWS MFA with temporary credentials
- Encryption at rest (KMS) and in transit (TLS)
- Defense in depth approach

### Cost Optimization
- Ephemeral infrastructure pattern (85% cost reduction)
- Right-sized instances (t3.small/micro based on workload)
- Single NAT gateway (cost-conscious design)
- On-demand vs always-on analysis
- Automated backup/restore for data persistence
- Pay-per-use model ($0.27/hour vs $201/month always-on)

### Site Reliability Engineering
- Automated backup and restore procedures
- Reproducible environments (Terraform + GitOps)
- Comprehensive monitoring (Prometheus, Grafana, Loki)
- Pre-commit hooks for quality gates
- Disaster recovery procedures
- Infrastructure testing (tflint, tfsec, kubectl dry-run)
- Audit logging and compliance

</details>

---

## 📁 Project Structure

```
carian-constellation/
├── terraform/                          # Infrastructure as Code
│   ├── bootstrap/                      # One-time persistent resources
│   │   ├── main.tf                     # S3, DynamoDB, Route53
│   │   ├── secrets.tf                  # AWS Secrets Manager
│   │   ├── iam.tf                      # IAM policies
│   │   └── outputs.tf
│   │
│   ├── ephemeral/                      # Spin up/down resources
│   │   ├── main.tf
│   │   ├── networking.tf               # VPC, subnets, NAT
│   │   ├── eks-cluster.tf              # EKS with private endpoint
│   │   ├── tailscale.tf                # Zero Trust VPN relay
│   │   ├── security.tf                 # Security groups, KMS
│   │   └── backend.hcl                 # S3 backend configuration
│   │
│   ├── persistent/                     # Kubernetes controllers
│   │   ├── alb-controller.tf           # AWS Load Balancer (Helm)
│   │   ├── external-secrets.tf         # External Secrets Operator (Helm)
│   │   ├── cert-manager.tf             # TLS automation (Helm)
│   │   ├── monitoring.tf               # kube-prometheus-stack (Helm)
│   │   ├── storage.tf                  # EBS CSI driver (Helm)
│   │   └── backend.hcl                 # S3 backend configuration
│   │
│   └── modules/                        # Reusable Terraform modules
│       ├── vpc/
│       ├── eks/
│       └── irsa/
│
├── kubernetes/                         # Kubernetes manifests
│   ├── namespaces/                     # Namespace definitions + quotas
│   ├── applications/                   # Service deployments
│   │   ├── open-webui/
│   │   ├── perplexica/
│   │   ├── authelia/
│   │   └── postgresql/
│   ├── secrets/                        # External Secrets configurations
│   ├── ingress/                        # ALB Ingress resources
│   └── monitoring/                     # ServiceMonitors, alerts
│
├── scripts/                            # Operational automation
│   ├── constellation-up.sh             # 🚀 Deploy everything
│   ├── constellation-down.sh           # 💥 Destroy with backup
│   ├── constellation-status.sh         # Check current state
│   ├── backup-data.sh                  # S3 backup automation
│   ├── restore-data.sh                 # S3 restore automation
│   └── security/                       # Security setup scripts
│       ├── setup-tailscale.sh
│       ├── generate-kubectl-certs.sh
│       └── configure-yubikey.sh
│
├── docs/                               # Detailed documentation
│   ├── architecture.md                 # Architecture decisions
│   ├── security-model.md               # Security implementation
│   ├── cost-optimization.md            # Cost breakdown
│   └── troubleshooting.md              # Common issues
│
├── .pre-commit-config.yaml             # Quality gates
├── .tflint.hcl                         # Terraform linting
├── .gitignore                          # Excludes secrets
├── CLAUDE.md                           # AI agent context (gitignored)
└── README.md                           # This file
```

---

## 🛠️ Technology Stack

### Infrastructure Layer

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Cloud Provider** | AWS (us-east-1) | Infrastructure hosting |
| **Container Orchestration** | AWS EKS 1.28+ | Kubernetes management |
| **Infrastructure as Code** | Terraform 1.5+ | Reproducible infrastructure |
| **State Management** | S3 + DynamoDB | Terraform remote state + locking |
| **Networking** | AWS VPC | Private subnets, NAT gateway |
| **Zero Trust VPN** | Tailscale | Secure access to private endpoints |
| **Load Balancing** | AWS ALB | Internal load balancer for services |

### Security Layer

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Network Security** | Tailscale (WireGuard) | Zero Trust VPN access |
| **AWS Authentication** | aws-vault + MFA | Temporary credentials with MFA |
| **kubectl Authentication** | Client certificates | Certificate-based cluster access |
| **Application Authentication** | Authelia + YubiKey | WebAuthn/FIDO2 hardware MFA |
| **Secret Management** | AWS Secrets Manager | Centralized secret storage |
| **Secret Sync** | External Secrets Operator | Kubernetes secret synchronization |
| **Encryption (Rest)** | AWS KMS | Data encryption |
| **Encryption (Transit)** | cert-manager + TLS | Certificate automation |
| **Service Authentication** | IRSA | IAM roles for service accounts |

### Kubernetes Layer

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Ingress** | AWS Load Balancer Controller | ALB-based ingress |
| **Certificate Management** | cert-manager | Automatic TLS certificates |
| **Secret Synchronization** | External Secrets Operator | AWS Secrets → K8s Secrets |
| **Storage** | EBS CSI Driver | Persistent volume provisioning |
| **Monitoring** | Prometheus | Metrics collection |
| **Visualization** | Grafana | Dashboards and alerts |
| **Logging** | Loki | Log aggregation |
| **Alerting** | Alertmanager | Alert routing |

### Application Layer

| Service | Container Image | Purpose |
|---------|----------------|---------|
| **Open-WebUI** | ghcr.io/open-webui/open-webui | AI chat interface |
| **Perplexica** | ghcr.io/ItzCrazyKns/perplexica | AI-powered search |
| **SearXNG** | searxng/searxng | Meta-search engine |
| **Authelia** | authelia/authelia | Authentication gateway |
| **PostgreSQL** | postgres:16 | Database |
| **Redis** | redis:7-alpine | Session storage |

---

## 📅 Project Phases

### Phase 1: Bootstrap Infrastructure - **In Progress**
- [x] Project planning and architecture design
- [x] Repository setup with pre-commit hooks
- [x] Documentation and directory structure
- [ ] Terraform bootstrap module (S3, Route53, Secrets Manager)
- [ ] AWS account setup with MFA
- [ ] Tailscale account configuration
- [ ] Domain configuration and DNS setup

### Phase 2: Ephemeral Infrastructure
- [ ] Terraform ephemeral module (VPC, EKS, nodes)
- [ ] Tailscale relay deployment
- [ ] Private EKS endpoint configuration
- [ ] kubectl access setup with certificates

### Phase 3: Kubernetes Controllers
- [ ] Terraform persistent module (Helm charts)
- [ ] AWS Load Balancer Controller with IRSA
- [ ] External Secrets Operator with IRSA
- [ ] cert-manager deployment
- [ ] EBS CSI driver with IRSA
- [ ] kube-prometheus-stack deployment

### Phase 4: Application Migration
- [ ] Namespace creation with quotas
- [ ] PostgreSQL deployment with persistent storage
- [ ] Redis deployment
- [ ] Authelia with WebAuthn configuration
- [ ] Open-WebUI migration
- [ ] Perplexica migration
- [ ] Ingress and service configuration

### Phase 5: Automation & Testing
- [ ] Backup automation scripts
- [ ] Restore automation scripts
- [ ] constellation-up.sh script
- [ ] constellation-down.sh script
- [ ] End-to-end testing
- [ ] Cost validation

### Phase 6: Documentation & Polish
- [ ] Operational documentation
- [ ] Troubleshooting guides
- [ ] Security documentation
- [ ] Cost optimization analysis

---

## 📄 License

MIT License - See LICENSE file for details

---

## 🙏 Acknowledgments

**Inspired By**:
- [Carian Observatory](../carian-observatory) - The local-only Docker Compose foundation
- [Elden Ring](https://eldenring.wiki.fextralife.com/Caria+Manor) - Naming theme
- Cisco's Zero Trust security architecture
- AWS EKS Best Practices Guide
- Cloud Native Computing Foundation patterns
