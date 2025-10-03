# Ephemeral Infrastructure - Carian Constellation

This Terraform configuration creates **ephemeral** (short-lived, on-demand) infrastructure for the Carian Constellation project. These resources are designed to be created when you need the cluster and destroyed when you don't to optimize costs.

## 📋 What Gets Created

### 🌐 Networking (VPC)
- **VPC** with public and private subnets across 2 Availability Zones
- **Internet Gateway** for public subnet internet access
- **NAT Gateway** (single, cost-optimized) for private subnet outbound traffic
- **VPC Endpoints** for S3, ECR, and CloudWatch (avoid NAT costs)
- **Route tables** configured for Kubernetes
- **Subnet tagging** for EKS auto-discovery

### ☸️ EKS Cluster
- **EKS Control Plane** (Kubernetes 1.28+)
- **Managed Node Group** with 2-4 nodes (t3.small by default)
- **Add-ons**: CoreDNS, kube-proxy, VPC CNI, EBS CSI driver
- **IRSA (IAM Roles for Service Accounts)** enabled
- **Control plane logging** to CloudWatch
- **Secrets encryption** with KMS

### 🔐 Security
- **KMS Keys** for EKS secrets and EBS volume encryption
- **Security Groups** for cluster, nodes, ALB, and VPC endpoints
- **IAM Roles** with least-privilege policies
- **IMDSv2** required on all instances
- **Network policies** ready for Calico/Cilium

### 🚇 Tailscale Relay
- **EC2 instance** (t3.micro) acting as Tailscale subnet router
- **Advertises VPC CIDR** to your Tailscale network
- **Secure access** to private EKS cluster without public endpoints
- **CloudWatch monitoring** with custom metrics
- **SSM Session Manager** access (no SSH keys needed)
- **Health checks** via CloudWatch alarms

### 📊 Monitoring & Logging
- **CloudWatch Log Groups** for cluster and application logs
- **CloudWatch Alarms** for Tailscale relay health
- **Metrics** for node and relay resource usage
- **Log retention** configured (7 days default)

---

## 💰 Estimated Costs

| Component | Monthly Cost | Notes |
|-----------|-------------|-------|
| EKS Control Plane | $73.00 | Per cluster (fixed) |
| EC2 Nodes (2x t3.small) | ~$30.00 | On-demand pricing |
| NAT Gateway | $32.40 | Single gateway |
| EBS Volumes (40 GB total) | $3.20 | gp3 storage |
| Tailscale Relay (t3.micro) | $10.08 | On-demand pricing |
| Data Transfer | Variable | ~$10-50/month typical |
| **TOTAL (running 24/7)** | **~$150-200/month** | Full infrastructure |
| **TOTAL (8hrs/day, 5 days/week)** | **~$50-70/month** | With ephemeral strategy |

### 💡 Cost Optimization Tips
1. **Use SPOT instances** for nodes: `node_capacity_type = "SPOT"` (save 60-70%)
2. **Destroy when not in use**: `terraform destroy` (save 100% on idle time)
3. **Use smaller instances**: Try `t3.micro` nodes for dev workloads
4. **Single NAT gateway**: Already enabled (saves $32.40/month per extra NAT)
5. **Disable public endpoint**: Use Tailscale only (saves egress costs)

---

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Install required tools
brew install terraform awscli kubectl

# Configure AWS credentials
aws configure

# Install Tailscale (optional but recommended)
brew install tailscale
sudo tailscale up
```

### 2. Generate Tailscale Auth Key

1. Go to [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys)
2. Generate a new **ephemeral**, **reusable** auth key
3. Add tags: `tag:server`, `tag:relay`
4. Copy the key (starts with `tskey-auth-`)

### 3. Configure Variables

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

**Minimum required configuration:**
```hcl
# terraform.tfvars
project_name        = "carian-constellation"
environment         = "dev"
aws_region          = "us-east-1"
owner_email         = "your.email@example.com"
github_username     = "yourusername"
domain_name         = "yourdomain.com"

# Tailscale (get from: https://login.tailscale.com/admin/settings/keys)
tailscale_auth_key = "tskey-auth-xxxxxxxxxxxxx"
my_tailscale_ip    = "100.x.x.x"  # Get from: tailscale ip -4

# Cost optimization
node_capacity_type = "SPOT"  # Use spot instances for 60-70% savings
```

### 4. Initialize Terraform

```bash
# Initialize Terraform (downloads providers)
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan
```

### 5. Deploy Infrastructure

```bash
# Deploy everything
terraform apply

# Or auto-approve (use carefully!)
terraform apply -auto-approve
```

**Deployment time**: ~15-20 minutes

### 6. Configure Access

```bash
# Get cluster credentials
aws eks update-kubeconfig --region us-east-1 --name constellation-dev

# Verify cluster access
kubectl get nodes
kubectl get pods --all-namespaces

# View outputs
terraform output
```

### 7. Configure Tailscale Relay

```bash
# Get Tailscale relay IP
RELAY_IP=$(terraform output -raw tailscale_relay_public_ip)

# Check relay setup (via SSM)
aws ssm start-session --target $(terraform output -raw tailscale_relay_instance_id)

# On the relay, view setup status
cat /root/tailscale-ready
```

**Enable subnet routing:**
1. Visit [Tailscale Admin Console](https://login.tailscale.com/admin/machines)
2. Find `constellation-relay-us-east-1`
3. Click **"Edit route settings"**
4. Enable **"Use as subnet router"**
5. Approve advertised routes (`10.0.0.0/16`)

### 8. Test Connectivity

```bash
# From your laptop (on Tailscale), test connectivity
ping <tailscale-relay-internal-ip>

# Try accessing cluster via Tailscale
kubectl get nodes
```

---

## 🗑️ Destroying Infrastructure

When you're done working, **destroy everything** to stop costs:

```bash
# Destroy all ephemeral resources
terraform destroy

# Or auto-approve (use carefully!)
terraform destroy -auto-approve
```

**⚠️ WARNING**: This will delete:
- EKS cluster and all running workloads
- All EBS volumes (data will be lost unless backed up)
- VPC and networking
- Tailscale relay

**Destruction time**: ~10-15 minutes

---

## 📁 File Structure

```
ephemeral/
├── main.tf                    # Core Terraform config & providers
├── variables.tf               # Input variables with defaults
├── locals.tf                  # Local values & tagging
├── networking.tf              # VPC, subnets, NAT, endpoints
├── security.tf                # KMS, security groups, logs
├── eks-cluster.tf             # EKS cluster & node groups
├── tailscale.tf               # Tailscale relay instance
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example configuration
├── .gitignore                 # Ignore sensitive files
├── README.md                  # This file
└── templates/
    └── tailscale-relay-userdata.sh  # Tailscale bootstrap script
```

---

## 🔧 Advanced Configuration

### Using Spot Instances (60-70% savings)

```hcl
# terraform.tfvars
node_capacity_type = "SPOT"
node_instance_types = ["t3.small", "t3a.small"]  # Multiple types for availability
```

### Scaling Node Group

```hcl
# terraform.tfvars
node_desired_size = 3
node_min_size     = 2
node_max_size     = 10

# Enable cluster autoscaler in persistent infrastructure
```

### Changing Kubernetes Version

```hcl
# terraform.tfvars
kubernetes_version = "1.29"  # Always use latest stable
```

### High Availability NAT Gateway

```hcl
# terraform.tfvars
single_nat_gateway = false  # One NAT per AZ (more resilient, more expensive)
```

### Elastic IP for Tailscale Relay

```hcl
# terraform.tfvars
use_tailscale_eip = true  # Stable IP address ($3.60/month)
```

---

## 🛠️ Troubleshooting

### Cluster Not Accessible

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name constellation-dev

# Check cluster status
aws eks describe-cluster --name constellation-dev --region us-east-1

# Verify security group allows your IP
# (or use Tailscale relay)
```

### Tailscale Relay Not Working

```bash
# Connect via SSM
aws ssm start-session --target $(terraform output -raw tailscale_relay_instance_id)

# Check Tailscale status
sudo tailscale status

# View setup logs
cat /var/log/tailscale-setup.log

# Restart Tailscale
sudo systemctl restart tailscaled

# Re-authenticate
sudo tailscale up --authkey=<new-key>
```

### Node Group Not Launching

```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name constellation-dev \
  --nodegroup-name constellation-dev-general \
  --region us-east-1

# Common issues:
# 1. Insufficient EC2 capacity (try different instance type)
# 2. Service limits reached (request limit increase)
# 3. Security group blocking traffic
```

### High Costs

```bash
# View cost breakdown
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE

# Top cost optimizations:
# 1. Use SPOT instances
# 2. Destroy when not in use
# 3. Use smaller instance types
# 4. Single NAT gateway
```

---

## 🔐 Security Best Practices

### ✅ Already Implemented
- [x] Secrets encryption at rest (KMS)
- [x] EBS volume encryption
- [x] Private cluster endpoint (with Tailscale)
- [x] IMDSv2 required
- [x] Least-privilege IAM policies
- [x] Security group restrictions
- [x] VPC endpoints (avoid NAT)
- [x] CloudWatch logging enabled
- [x] SSM Session Manager (no SSH keys)

### 🎯 Additional Recommendations
- [ ] Enable network policies (Calico/Cilium)
- [ ] Add pod security standards
- [ ] Configure RBAC policies
- [ ] Enable admission controllers
- [ ] Add runtime security (Falco)
- [ ] Implement secret scanning
- [ ] Enable audit logging

---

## 📚 Related Documentation

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [Tailscale Subnet Routers](https://tailscale.com/kb/1019/subnets/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

## 🆘 Support

**Issues or questions?**
1. Check logs: `terraform show`, CloudWatch, SSM Session Manager
2. Validate configuration: `terraform validate`
3. Review AWS documentation
4. Check GitHub issues for similar problems

---

## 📝 License

See project root LICENSE file.

---

**Created by**: Stalheim  
**Project**: Carian Constellation  
**Last Updated**: October 2025
