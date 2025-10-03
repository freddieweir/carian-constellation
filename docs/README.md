# Carian Constellation Documentation

Detailed technical documentation for the Carian Constellation platform.

## Documentation Files

### `architecture.md`
**Purpose**: Detailed architecture decisions and design rationale

**Contents**:
- High-level system architecture
- Three-layer Terraform module design
- Zero Trust security layers
- Network topology and VPC design
- Namespace architecture
- Data flow diagrams
- Technology selection rationale

### `security-model.md`
**Purpose**: Comprehensive security implementation guide

**Contents**:
- Four-layer Zero Trust architecture
- Tailscale Zero Trust VPN setup
- AWS IAM with mandatory MFA
- YubiKey WebAuthn configuration
- IRSA (IAM Roles for Service Accounts) implementation
- Encryption at rest and in transit
- Secret management with AWS Secrets Manager
- Audit logging and compliance

### `cost-optimization.md`
**Purpose**: Cost analysis and optimization strategies

**Contents**:
- Detailed cost breakdown by component
- Ephemeral vs always-on comparison
- Usage pattern scenarios
- Cost optimization techniques
- SPOT instance analysis
- Monthly budget tracking
- Cost-saving recommendations

### `troubleshooting.md`
**Purpose**: Common issues and their solutions

**Contents**:
- Terraform state issues
- EKS cluster connectivity problems
- External Secrets sync failures
- Pod startup failures
- ALB Ingress issues
- Backup/restore problems
- Cost overruns
- Tailscale connectivity issues

### `deployment-guide.md`
**Purpose**: Step-by-step deployment instructions

**Contents**:
- Prerequisites and account setup
- Bootstrap infrastructure deployment
- Ephemeral infrastructure deployment
- Kubernetes controller installation
- Application deployment
- Verification and testing procedures

### `operations-guide.md`
**Purpose**: Day-to-day operational procedures

**Contents**:
- Starting and stopping constellation
- Monitoring and alerting
- Backup and restore procedures
- Updating applications
- Scaling services
- Certificate management
- Log analysis

### `interview-prep.md`
**Purpose**: Interview talking points and demonstrations

**Contents**:
- Skills demonstrated by this project
- Common interview questions with answers
- Live demo scripts
- Cost optimization explanations
- Security architecture walkthrough
- SRE practice examples

## Quick Reference

### Architecture Diagrams
See `architecture.md` for:
- Network topology diagram
- Security layer diagram
- Terraform module dependencies
- Kubernetes namespace architecture
- Data flow diagrams

### Cost Calculators
See `cost-optimization.md` for:
- Hourly cost breakdown
- Monthly usage scenarios
- Always-on vs ephemeral comparison
- SPOT instance savings calculator

### Security Checklist
See `security-model.md` for:
- Pre-deployment security review
- IRSA configuration checklist
- Secret management verification
- Audit logging setup

### Common Commands
See `operations-guide.md` for:
- Deployment commands
- Monitoring commands
- Backup/restore commands
- Troubleshooting commands

## Documentation Standards

All documentation follows these principles:

**Clarity**:
- Write for future you (6 months from now)
- Assume reader knows Kubernetes/AWS basics
- Explain "why" not just "what"

**Accuracy**:
- All code examples must be tested
- Keep commands up-to-date with latest versions
- Include expected output for verification

**Completeness**:
- Cover happy path and error cases
- Include troubleshooting for common issues
- Provide context for architectural decisions

**Structure**:
- Use headings for scanability
- Include diagrams for complex concepts
- Provide quick reference sections

## Using This Documentation

### For Development
1. Read `architecture.md` for design understanding
2. Read `deployment-guide.md` for step-by-step setup
3. Refer to `operations-guide.md` for daily tasks

### For Troubleshooting
1. Check `troubleshooting.md` for your specific issue
2. If not found, check CloudWatch logs
3. Review `operations-guide.md` for diagnostic commands

### For Interviews
1. Review `interview-prep.md` for talking points
2. Practice demo from `operations-guide.md`
3. Understand cost breakdown from `cost-optimization.md`
4. Know security model from `security-model.md`

### For Cost Optimization
1. Read `cost-optimization.md` for strategies
2. Run cost-tracker.sh weekly
3. Adjust usage patterns to stay in budget
4. Consider SPOT instances if needed

## Contributing to Documentation

When adding new documentation:

1. **Keep it practical** - Focus on real-world usage
2. **Include examples** - Tested commands and code
3. **Explain context** - Why decisions were made
4. **Update diagrams** - Visual aids for complex topics
5. **Test procedures** - Verify all steps work
6. **Link related docs** - Cross-reference when helpful

## Documentation TODOs

As the project develops, create these documents:

- [ ] `architecture.md` - System design and decisions
- [ ] `security-model.md` - Zero Trust implementation
- [ ] `cost-optimization.md` - Cost analysis and strategies
- [ ] `troubleshooting.md` - Common issues and solutions
- [ ] `deployment-guide.md` - Step-by-step deployment
- [ ] `operations-guide.md` - Day-to-day operations
- [ ] `interview-prep.md` - Interview talking points
- [ ] `disaster-recovery.md` - DR procedures
- [ ] `monitoring-setup.md` - Prometheus/Grafana configuration
- [ ] `backup-strategy.md` - Backup and restore procedures

## Quick Links

- **Main README**: [../README.md](../README.md)
- **Terraform README**: [../terraform/README.md](../terraform/README.md)
- **Kubernetes README**: [../kubernetes/README.md](../kubernetes/README.md)
- **Scripts README**: [../scripts/README.md](../scripts/README.md)
- **CLAUDE.md**: Context file for AI agents (gitignored)
