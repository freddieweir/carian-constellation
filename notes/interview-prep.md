# Interview Preparation Notes

**Private notes for discussing Carian Constellation in technical conversations**

## Terraform State Management

**Question**: "How do you manage Terraform state for multiple environments?"

**Approach**:
I implemented a three-layer architecture with bootstrap, ephemeral, and persistent modules. Bootstrap uses local backend to create the S3 bucket (chicken-egg problem), then ephemeral and persistent modules use S3 with partial backend configuration. State locking via DynamoDB prevents concurrent modifications. Each module has isolated state for independent lifecycle management.

**Key Details**:
- Bootstrap creates the S3 bucket it will later use for remote state
- `backend.hcl` files keep sensitive backend config out of version control
- DynamoDB table prevents concurrent Terraform runs
- Each module has separate state files for targeted updates

## Kubernetes Secrets Management

**Question**: "How do you handle secrets in Kubernetes?"

**Approach**:
I use AWS Secrets Manager with External Secrets Operator. Secrets are stored in AWS Secrets Manager, and the operator syncs them to Kubernetes Secrets. The operator uses IRSA for authentication, so no static credentials. This keeps secrets centralized, auditable, and outside version control.

**Key Details**:
- No secrets in git repositories (ever)
- IRSA means no AWS credentials stored in cluster
- External Secrets Operator refreshes every hour automatically
- CloudTrail audit logging for all secret access
- Can rotate secrets in AWS and they sync automatically

## Kubernetes Security

**Question**: "Describe your approach to securing a Kubernetes cluster"

**Approach**:
I implemented Zero Trust principles with four security layers:
1. **Network layer**: Tailscale VPN with private EKS endpoints only
2. **Infrastructure layer**: AWS MFA for all operations
3. **Application layer**: Authelia with YubiKey WebAuthn for service access
4. **Service layer**: Kubernetes RBAC with certificate-based auth

Every layer requires explicit authentication - no implicit trust.

**Key Details**:
- EKS has NO public endpoint (100% private)
- Cannot access without Tailscale authentication first
- Then need YubiKey tap for each service
- kubectl uses client certificates (not bearer tokens)
- NetworkPolicies isolate namespaces
- Pod Security Standards prevent privilege escalation

## Cost Optimization

**Question**: "How would you reduce costs for a development EKS cluster?"

**Approach**:
I implemented ephemeral infrastructure where the cluster is destroyed when not in use. Data is backed up to S3 before teardown and restored after spin-up. This reduces a $201/month always-on cluster to $17/month for regular use - 91% cost reduction. Also used right-sized instances and single NAT gateway for additional savings.

**Key Details**:
- Spin-up: 12-18 minutes (automated)
- Tear-down: 5-8 minutes (automated)
- Backup/restore: Fully automated, no manual steps
- EKS control plane: $73/month → $4/month (40 hours use)
- Worker nodes: Right-sized for workload (t3.small vs t3.large)
- Single NAT gateway saves $32/month per extra NAT avoided

**Future Optimizations**:
- SPOT instances could reduce costs another 60-70%
- Fargate Spot for even more savings
- Reserved instances if usage becomes predictable

## Infrastructure Reliability

**Question**: "How do you ensure infrastructure reliability?"

**Approach**:
I use Infrastructure as Code for reproducibility - entire environment can be recreated in 15 minutes. Automated backups to S3 before destruction ensure data persistence. Comprehensive monitoring with Prometheus and Grafana provides observability. Pre-commit hooks enforce security (gitleaks, tfsec) and quality (terraform validate, tflint). All changes are audited via CloudTrail and EKS logs.

**Key Details**:
- Everything in Terraform (no manual ClickOps)
- Pre-commit hooks prevent bad commits (security, quality)
- Automated backups before ANY infrastructure destruction
- Full monitoring stack (Prometheus, Grafana, Loki, Alertmanager)
- Can recreate from scratch in under 20 minutes
- All AWS API calls logged (CloudTrail)
- All kubectl commands audited (EKS logs)

## IRSA (IAM Roles for Service Accounts)

**Question**: "How do you give Kubernetes pods AWS permissions?"

**Approach**:
I use IRSA (IAM Roles for Service Accounts) which creates IAM roles with trust relationships to the EKS OIDC provider. Each service account gets its own IAM role with specific permissions. No AWS credentials stored in the cluster - everything uses temporary credentials via STS.

**Key Details**:
- ALB Controller has EC2/ELB permissions via IRSA
- External Secrets Operator has Secrets Manager read via IRSA
- EBS CSI driver has EC2 volume permissions via IRSA
- No static AWS access keys anywhere
- Credentials rotate automatically (temporary STS tokens)
- Least privilege per service (not one admin role)

## Why This Project?

**If asked "Why build this?"**:

"I wanted to push myself beyond Docker Compose into real cloud infrastructure. Carian Observatory works great locally, but I wanted to understand how to run it at scale with proper security and cost controls. The ephemeral infrastructure pattern was the interesting challenge - how do you destroy everything when not in use but make it come back exactly the same way? That led to learning about Terraform state management, backup/restore automation, and EKS lifecycle management."

**Focus on**:
- Technical challenge and learning
- Practical problem-solving (cost reduction)
- Security interest (Zero Trust, hardware MFA)
- Systems thinking (how pieces fit together)

**Avoid**:
- "For my resume" or "to get a job"
- "To impress recruiters"
- Anything that sounds like box-checking
- Overly formal or corporate-speak

## Project Challenges & Solutions

### Challenge: EKS Costs Too High
**Problem**: Always-on EKS costs $200+/month
**Solution**: Ephemeral infrastructure with automated backup/restore
**Learning**: Terraform lifecycle management, S3 versioning, automated testing

### Challenge: Too Many Secrets
**Problem**: API keys, certificates, passwords scattered everywhere
**Solution**: AWS Secrets Manager + External Secrets Operator
**Learning**: IRSA, Kubernetes operators, secret rotation

### Challenge: Private EKS Access
**Problem**: Can't expose EKS publicly for security
**Solution**: Tailscale Zero Trust VPN with subnet routing
**Learning**: Zero Trust architecture, VPN routing, private endpoints

### Challenge: Certificate Management
**Problem**: Manual TLS certificate management doesn't scale
**Solution**: cert-manager with automatic renewal
**Learning**: Kubernetes operators, ACME protocol, cert lifecycle

## Technical Depth Areas

### Strong Understanding
- Terraform (modules, state management, providers)
- Kubernetes (deployments, services, namespaces, RBAC)
- AWS (EKS, VPC, IAM, Secrets Manager, S3)
- Docker (containers, images, registries)
- Security (Zero Trust, hardware MFA, encryption)

### Learned Through This Project
- IRSA (IAM Roles for Service Accounts)
- External Secrets Operator
- Tailscale VPN and subnet routing
- EKS private endpoints
- Cost optimization at scale
- Backup/restore automation

### Still Learning
- Service mesh patterns (Istio/Linkerd)
- GitOps with ArgoCD/Flux
- Kubernetes network policies (basics done, advanced WIP)
- AWS cost allocation tags and FinOps
- Observability best practices (Prometheus/Grafana configured, alerts WIP)

## Conversation Starters

Good topics to discuss if conversation goes that direction:

1. **Ephemeral Infrastructure Pattern**
   - Tradeoffs: Cost vs convenience
   - Backup/restore automation challenges
   - When it makes sense vs when it doesn't

2. **Zero Trust Security**
   - Multiple authentication layers
   - Hardware MFA benefits and challenges
   - Private-only infrastructure approach

3. **Terraform Architecture**
   - Bootstrap/ephemeral/persistent split
   - State management strategies
   - Module design patterns

4. **Kubernetes Operators**
   - External Secrets Operator deep dive
   - ALB Controller configuration
   - cert-manager automation

5. **Cost Optimization**
   - Right-sizing instances
   - Ephemeral vs SPOT vs Reserved
   - FinOps principles in practice
