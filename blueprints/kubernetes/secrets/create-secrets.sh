#!/bin/bash
# ============================================================================
# Create Secrets in AWS Secrets Manager
# ============================================================================
# This script creates all required secrets for Carian Constellation in AWS Secrets Manager
#
# Usage: ./create-secrets.sh
#
# Prerequisites:
# - AWS CLI configured with appropriate credentials
# - jq installed (for JSON processing)
# ============================================================================

set -euo pipefail

PROJECT="carian-constellation"
REGION="${AWS_REGION:-us-east-1}"

echo "=========================================="
echo "Creating Secrets in AWS Secrets Manager"
echo "Project: $PROJECT"
echo "Region: $REGION"
echo "=========================================="
echo ""

# Function to create or update a secret
create_secret() {
    local secret_name=$1
    local secret_value=$2
    local description=$3
    
    echo "Creating secret: $secret_name"
    
    # Check if secret exists
    if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$REGION" &>/dev/null; then
        echo "  → Secret exists, updating value..."
        aws secretsmanager put-secret-value \
            --secret-id "$secret_name" \
            --secret-string "$secret_value" \
            --region "$REGION" \
            --output json > /dev/null
        echo "  ✓ Updated"
    else
        echo "  → Creating new secret..."
        aws secretsmanager create-secret \
            --name "$secret_name" \
            --description "$description" \
            --secret-string "$secret_value" \
            --region "$REGION" \
            --tags Key=Project,Value=carian-constellation Key=ManagedBy,Value=script \
            --output json > /dev/null
        echo "  ✓ Created"
    fi
    echo ""
}

# Generate random passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
OPENWEBUI_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

echo "📝 Generated secure random passwords"
echo ""

# ============================================================================
# PostgreSQL Secrets
# ============================================================================

echo "🐘 PostgreSQL Secrets"
echo "─────────────────────"

create_secret \
    "$PROJECT/postgresql/username" \
    "carianuser" \
    "PostgreSQL database username"

create_secret \
    "$PROJECT/postgresql/password" \
    "$POSTGRES_PASSWORD" \
    "PostgreSQL database password"

# ============================================================================
# Open WebUI Secrets
# ============================================================================

echo "🤖 Open WebUI Secrets"
echo "─────────────────────"

# Prompt for OpenAI API key
echo "Enter your OpenAI API key (or press Enter to skip):"
read -r -s OPENAI_API_KEY
echo ""

if [ -n "$OPENAI_API_KEY" ]; then
    create_secret \
        "$PROJECT/open-webui/openai-api-key" \
        "$OPENAI_API_KEY" \
        "OpenAI API key for Open WebUI"
else
    echo "  ⏭️  Skipping OpenAI API key (you can add it later)"
    echo ""
fi

create_secret \
    "$PROJECT/open-webui/secret-key" \
    "$OPENWEBUI_SECRET" \
    "Secret key for Open WebUI session management"

# Create database URL
DATABASE_URL="postgresql://carianuser:${POSTGRES_PASSWORD}@postgresql-client.carian-data.svc.cluster.local:5432/cariandb"

create_secret \
    "$PROJECT/open-webui/database-url" \
    "$DATABASE_URL" \
    "PostgreSQL database URL for Open WebUI"

# ============================================================================
# Perplexica Secrets
# ============================================================================

echo "🔍 Perplexica Secrets"
echo "─────────────────────"

# Use same OpenAI key for Perplexica if provided
if [ -n "$OPENAI_API_KEY" ]; then
    create_secret \
        "$PROJECT/perplexica/openai-api-key" \
        "$OPENAI_API_KEY" \
        "OpenAI API key for Perplexica"
else
    echo "  ⏭️  Skipping OpenAI API key (add manually)"
    echo ""
fi

# Prompt for search API key (SearXNG, Brave, etc.)
echo "Enter your search API key (SearXNG/Brave) (or press Enter to skip):"
read -r -s SEARCH_API_KEY
echo ""

if [ -n "$SEARCH_API_KEY" ]; then
    create_secret \
        "$PROJECT/perplexica/search-api-key" \
        "$SEARCH_API_KEY" \
        "Search API key for Perplexica"
else
    echo "  ⏭️  Skipping search API key (you can add it later)"
    echo ""
fi

# Generate SearXNG secret
SEARXNG_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

create_secret \
    "$PROJECT/perplexica/searxng-secret" \
    "$SEARXNG_SECRET" \
    "SearXNG secret key for session encryption"

# ============================================================================
# Grafana Secrets (Optional)
# ============================================================================

echo "📊 Grafana Secrets"
echo "─────────────────────"

# Prompt for Grafana admin password
echo "Enter Grafana admin password (or press Enter to generate):"
read -r -s GRAFANA_PASSWORD
echo ""

if [ -z "$GRAFANA_PASSWORD" ]; then
    GRAFANA_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    echo "  → Generated password: $GRAFANA_PASSWORD"
    echo "  ⚠️  Save this password! You'll need it to login to Grafana"
    echo ""
fi

create_secret \
    "$PROJECT/grafana/admin-password" \
    "$GRAFANA_PASSWORD" \
    "Grafana admin password"

# ============================================================================
# Summary
# ============================================================================

echo "=========================================="
echo "✅ All secrets created successfully!"
echo "=========================================="
echo ""
echo "📋 Summary:"
echo "  • PostgreSQL username: carianuser"
echo "  • PostgreSQL password: [stored in AWS Secrets Manager]"
echo "  • Open WebUI secret key: [generated]"
echo "  • OpenAI API key: [${OPENAI_API_KEY:+provided}${OPENAI_API_KEY:-not provided}]"
echo "  • Search API key: [${SEARCH_API_KEY:+provided}${SEARCH_API_KEY:-not provided}]"
echo "  • Grafana password: [stored in AWS Secrets Manager]"
echo ""
echo "📝 Next steps:"
echo "  1. Verify secrets in AWS console:"
echo "     https://console.aws.amazon.com/secretsmanager/home?region=$REGION"
echo ""
echo "  2. Deploy External Secrets Operator (if not already deployed):"
echo "     kubectl apply -f ../secrets/external-secrets.yaml"
echo ""
echo "  3. Verify secrets are synced to Kubernetes:"
echo "     kubectl get externalsecret -A"
echo "     kubectl get secret -n carian-data postgresql-credentials"
echo "     kubectl get secret -n carian-apps open-webui-secrets"
echo "     kubectl get secret -n carian-apps perplexica-secrets"
echo ""
echo "🔐 Security notes:"
echo "  • All secrets are encrypted at rest in AWS Secrets Manager"
echo "  • Kubernetes secrets are synced automatically every 1 hour"
echo "  • Never commit secrets to git!"
echo "  • Rotate secrets regularly (every 90 days recommended)"
echo ""
