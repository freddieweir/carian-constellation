#!/bin/bash
# Tailscale Subnet Router Setup Script
# This script installs and configures Tailscale as a subnet router

set -e

# Variables passed from Terraform
TAILSCALE_AUTH_KEY="${tailscale_auth_key}"
VPC_CIDR="${vpc_cidr}"
AWS_REGION="${region}"
CLUSTER_NAME="${cluster_name}"

# Logging
exec > >(tee /var/log/tailscale-setup.log)
exec 2>&1

echo "=========================================="
echo "Tailscale Subnet Router Setup"
echo "=========================================="
echo "VPC CIDR: $VPC_CIDR"
echo "AWS Region: $AWS_REGION"
echo "Cluster: $CLUSTER_NAME"
echo "Timestamp: $(date)"
echo "=========================================="

# Update system
echo "[1/6] Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install essential tools
echo "[2/6] Installing essential tools..."
apt-get install -y \
  curl \
  wget \
  jq \
  net-tools \
  htop \
  awscli

# Install Tailscale
echo "[3/6] Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

# Enable IP forwarding (required for subnet routing)
echo "[4/6] Configuring IP forwarding..."
cat >> /etc/sysctl.conf <<EOF

# Tailscale subnet router configuration
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

sysctl -p

# Connect to Tailscale and advertise VPC routes
echo "[5/6] Connecting to Tailscale network..."
tailscale up \
  --authkey="$TAILSCALE_AUTH_KEY" \
  --advertise-routes="$VPC_CIDR" \
  --advertise-exit-node=false \
  --accept-routes \
  --hostname="constellation-relay-$AWS_REGION" \
  --ssh

# Create systemd service to ensure Tailscale starts on boot
echo "[6/6] Creating systemd service..."
cat > /etc/systemd/system/tailscale-up.service <<EOF
[Unit]
Description=Tailscale subnet router
After=network.target tailscaled.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/tailscale up --authkey=$TAILSCALE_AUTH_KEY --advertise-routes=$VPC_CIDR --ssh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tailscale-up.service

# Verify Tailscale status
echo "=========================================="
echo "Tailscale Status:"
tailscale status
echo "=========================================="

# Create completion marker
cat > /root/tailscale-ready <<EOF
Tailscale subnet router configured successfully!
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
if command -v aws &> /dev/null; then
  INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
  aws cloudwatch put-metric-data \
    --region "$AWS_REGION" \
    --namespace "CarianConstellation" \
    --metric-name TailscaleRelayReady \
    --value 1 \
    --dimensions Cluster="$CLUSTER_NAME",InstanceId="$INSTANCE_ID" \
    --timestamp "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" || true
fi
