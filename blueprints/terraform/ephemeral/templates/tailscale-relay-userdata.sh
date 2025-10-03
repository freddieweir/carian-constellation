#!/bin/bash
# ============================================================================
# Tailscale Relay Setup Script for Carian Constellation
# ============================================================================
# This script configures an EC2 instance as a Tailscale relay/subnet router
# to provide secure access to the private EKS cluster and VPC resources.
#
# Templated variables are substituted by Terraform at deployment time.
# ============================================================================

set -euo pipefail

# ============================================================================
# Configuration Variables (Templated by Terraform)
# ============================================================================

TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY}"
AWS_REGION="${AWS_REGION}"
CLUSTER_NAME="${CLUSTER_NAME}"
VPC_CIDR="${VPC_CIDR}"
ENVIRONMENT="${ENVIRONMENT}"
PROJECT_NAME="${PROJECT_NAME}"

# ============================================================================
# Logging Setup
# ============================================================================

LOG_FILE="/var/log/tailscale-setup.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "=========================================="
echo "Tailscale Relay Setup - $(date)"
echo "=========================================="
echo "Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo "VPC CIDR: $VPC_CIDR"
echo "=========================================="

# ============================================================================
# System Updates and Dependencies
# ============================================================================

echo "📦 Updating system packages..."
yum update -y

echo "📦 Installing required packages..."
yum install -y \
  curl \
  wget \
  jq \
  htop \
  iotop \
  tcpdump \
  net-tools \
  bind-utils \
  awscli \
  amazon-cloudwatch-agent

# ============================================================================
# Tailscale Installation
# ============================================================================

echo "🔧 Installing Tailscale..."

# Add Tailscale repository
cat > /etc/yum.repos.d/tailscale.repo <<'EOF'
[tailscale-stable]
name=Tailscale stable
baseurl=https://pkgs.tailscale.com/stable/amazon-linux/2/$basearch
enabled=1
type=rpm
repo_gpgcheck=1
gpgcheck=0
gpgkey=https://pkgs.tailscale.com/stable/amazon-linux/2/repo.gpg
EOF

# Install Tailscale
yum install -y tailscale

# Enable and start Tailscaled service
systemctl enable --now tailscaled

echo "✅ Tailscale installed successfully"

# ============================================================================
# System Configuration for IP Forwarding
# ============================================================================

echo "🔧 Configuring system for IP forwarding..."

# Enable IPv4 forwarding permanently
cat >> /etc/sysctl.conf <<'EOF'

# Tailscale relay configuration
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

# Apply sysctl changes immediately
sysctl -p

echo "✅ IP forwarding enabled"

# ============================================================================
# Tailscale Authentication and Configuration
# ============================================================================

echo "🔐 Authenticating with Tailscale..."

# Authenticate and configure Tailscale as a subnet router
tailscale up \
  --authkey="$TAILSCALE_AUTH_KEY" \
  --advertise-routes="$VPC_CIDR" \
  --accept-routes \
  --hostname="constellation-relay-$AWS_REGION" \
  --advertise-tags="tag:server,tag:relay,tag:$ENVIRONMENT" \
  --ssh

# Wait for Tailscale to be ready
echo "⏳ Waiting for Tailscale to be ready..."
for i in {1..30}; do
  if tailscale status &>/dev/null; then
    echo "✅ Tailscale is ready"
    break
  fi
  echo "   Waiting... ($i/30)"
  sleep 2
done

# Display Tailscale status
echo ""
echo "📊 Tailscale Status:"
tailscale status

echo ""
echo "🌐 Tailscale IP addresses:"
tailscale ip -4
tailscale ip -6 || true

# ============================================================================
# AWS CLI Configuration
# ============================================================================

echo "🔧 Configuring AWS CLI..."

# Set default region
aws configure set default.region "$AWS_REGION"

# Verify AWS CLI access
echo "📊 AWS Identity:"
aws sts get-caller-identity

# ============================================================================
# EKS Access Configuration
# ============================================================================

echo "🔧 Configuring EKS access..."

# Install kubectl
echo "📦 Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Verify kubectl installation
kubectl version --client

# Update kubeconfig for EKS cluster access
echo "🔐 Configuring kubectl for EKS cluster..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

# Test cluster access
echo "✅ Testing EKS cluster access..."
if kubectl get nodes; then
  echo "✅ Successfully connected to EKS cluster"
else
  echo "⚠️  Could not connect to EKS cluster (this is normal if cluster is still provisioning)"
fi

# ============================================================================
# CloudWatch Agent Configuration
# ============================================================================

echo "🔧 Configuring CloudWatch agent..."

# Create CloudWatch agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/tailscale-setup.log",
            "log_group_name": "/constellation/$CLUSTER_NAME/tailscale-relay",
            "log_stream_name": "{instance_id}/setup",
            "retention_in_days": 7
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/constellation/$CLUSTER_NAME/tailscale-relay",
            "log_stream_name": "{instance_id}/system",
            "retention_in_days": 7
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "CarianConstellation",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {
            "name": "cpu_usage_idle",
            "rename": "CPU_IDLE",
            "unit": "Percent"
          },
          "cpu_usage_iowait"
        ],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "rename": "DISK_USED",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "rename": "MEM_USED",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      },
      "net": {
        "measurement": [
          "bytes_sent",
          "bytes_recv",
          "drop_in",
          "drop_out"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "eth0"
        ]
      }
    },
    "append_dimensions": {
      "InstanceId": "\${aws:InstanceId}",
      "InstanceType": "\${aws:InstanceType}",
      "ClusterName": "$CLUSTER_NAME",
      "Environment": "$ENVIRONMENT"
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

echo "✅ CloudWatch agent configured and started"

# ============================================================================
# Health Check Script
# ============================================================================

echo "🔧 Creating health check script..."

cat > /usr/local/bin/tailscale-health-check.sh <<'HEALTH_SCRIPT'
#!/bin/bash
# Health check for Tailscale relay

set -e

# Check if Tailscaled is running
if ! systemctl is-active --quiet tailscaled; then
  echo "ERROR: tailscaled service is not running"
  exit 1
fi

# Check if we have a Tailscale IP
if ! tailscale ip -4 &>/dev/null; then
  echo "ERROR: Tailscale IP not assigned"
  exit 1
fi

# Check if we can reach the Tailscale control plane
if ! tailscale status &>/dev/null; then
  echo "ERROR: Cannot communicate with Tailscale control plane"
  exit 1
fi

echo "✅ All health checks passed"
exit 0
HEALTH_SCRIPT

chmod +x /usr/local/bin/tailscale-health-check.sh

# Create systemd timer for health checks
cat > /etc/systemd/system/tailscale-health-check.service <<'EOF'
[Unit]
Description=Tailscale Relay Health Check
After=tailscaled.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/tailscale-health-check.sh
StandardOutput=journal
StandardError=journal
EOF

cat > /etc/systemd/system/tailscale-health-check.timer <<'EOF'
[Unit]
Description=Run Tailscale health check every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=tailscale-health-check.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now tailscale-health-check.timer

echo "✅ Health check configured"

# ============================================================================
# Firewall Configuration (Optional - EC2 security groups handle this)
# ============================================================================

# Note: We're relying on AWS Security Groups for firewall rules
# If you need additional iptables rules, add them here

# ============================================================================
# Monitoring and Alerting Setup
# ============================================================================

echo "🔧 Setting up custom metrics..."

# Create script to publish custom CloudWatch metrics
cat > /usr/local/bin/publish-tailscale-metrics.sh <<'METRICS_SCRIPT'
#!/bin/bash
# Publish Tailscale-specific metrics to CloudWatch

AWS_REGION="${AWS_REGION}"
CLUSTER_NAME="${CLUSTER_NAME}"
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)

# Check if Tailscale is connected
if tailscale status &>/dev/null; then
  CONNECTED=1
else
  CONNECTED=0
fi

# Publish metric
aws cloudwatch put-metric-data \
  --region "$AWS_REGION" \
  --namespace "CarianConstellation" \
  --metric-name TailscaleConnected \
  --value $CONNECTED \
  --dimensions Cluster="$CLUSTER_NAME",InstanceId="$INSTANCE_ID" \
  --timestamp "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
METRICS_SCRIPT

chmod +x /usr/local/bin/publish-tailscale-metrics.sh

# Add cron job to publish metrics every minute
cat > /etc/cron.d/tailscale-metrics <<'EOF'
* * * * * root /usr/local/bin/publish-tailscale-metrics.sh
EOF

echo "✅ Custom metrics configured"

# ============================================================================
# Final Setup and Documentation
# ============================================================================

echo "📝 Creating setup completion file..."

cat > /root/tailscale-ready <<EOF
========================================
Tailscale Relay Setup Complete!
========================================

Project: $PROJECT_NAME
Environment: $ENVIRONMENT
Cluster: $CLUSTER_NAME
Region: $AWS_REGION

Timestamp: $(date)
VPC CIDR advertised: $VPC_CIDR
Hostname: constellation-relay-$AWS_REGION
Tailscale IP: $(tailscale ip -4)

Next steps:
1. Approve subnet routes in Tailscale admin console:
   https://login.tailscale.com/admin/machines
   
2. Enable subnet routing for this machine

3. Verify connectivity from your laptop:
   ping $(tailscale ip -4)
   
EOF

cat /root/tailscale-ready

echo "✅ Tailscale relay setup complete!"
echo "=========================================="

# Send completion notification to CloudWatch (optional)
if command -v aws &>/dev/null; then
  INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
  aws cloudwatch put-metric-data \
    --region "$AWS_REGION" \
    --namespace "CarianConstellation" \
    --metric-name TailscaleRelayReady \
    --value 1 \
    --dimensions Cluster="$CLUSTER_NAME",InstanceId="$INSTANCE_ID" \
    --timestamp "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" || true
fi
