#!/usr/bin/env bash
#
# Create IAM user and attach Carian Constellation policies
# Usage: ./create-iam-user.sh [username]
#

set -euo pipefail

# Configuration
USERNAME="${1:-constellation-admin}"
POLICY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/policies" && pwd)"
REGION="${AWS_REGION:-us-east-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${BLUE}ℹ${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*"; }

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."

    if ! command -v aws &> /dev/null; then
        error "AWS CLI not found. Install with: brew install awscli"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        error "jq not found. Install with: brew install jq"
        exit 1
    fi

    # Verify AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured or invalid"
        error "Configure with: aws configure"
        exit 1
    fi

    success "Prerequisites OK"
}

# Get AWS account ID
get_account_id() {
    aws sts get-caller-identity --query Account --output text
}

# Create IAM user
create_user() {
    local username=$1

    info "Creating IAM user: ${username}"

    if aws iam get-user --user-name "${username}" &> /dev/null; then
        warn "User ${username} already exists"
        return 0
    fi

    aws iam create-user \
        --user-name "${username}" \
        --tags Key=Project,Value=CarianConstellation Key=ManagedBy,Value=Script

    success "Created IAM user: ${username}"
}

# Create IAM policies
create_policies() {
    local account_id=$1

    info "Creating IAM policies..."

    local policies=(
        "ConstellationBootstrap:01-bootstrap-infrastructure.json"
        "ConstellationEphemeral:02-ephemeral-infrastructure.json"
        "ConstellationKubernetesOps:03-kubernetes-operations.json"
    )

    for policy_def in "${policies[@]}"; do
        IFS=':' read -r policy_name policy_file <<< "${policy_def}"
        local policy_arn="arn:aws:iam::${account_id}:policy/${policy_name}"

        # Check if policy exists
        if aws iam get-policy --policy-arn "${policy_arn}" &> /dev/null; then
            warn "Policy ${policy_name} already exists"

            # Create new version
            info "Creating new version of ${policy_name}..."
            aws iam create-policy-version \
                --policy-arn "${policy_arn}" \
                --policy-document "file://${POLICY_DIR}/${policy_file}" \
                --set-as-default
            success "Updated policy: ${policy_name}"
        else
            # Create new policy
            info "Creating policy: ${policy_name}..."
            aws iam create-policy \
                --policy-name "${policy_name}" \
                --policy-document "file://${POLICY_DIR}/${policy_file}" \
                --description "Carian Constellation - ${policy_name}" \
                --tags Key=Project,Value=CarianConstellation Key=ManagedBy,Value=Script
            success "Created policy: ${policy_name}"
        fi
    done
}

# Attach policies to user
attach_policies() {
    local username=$1
    local account_id=$2

    info "Attaching policies to user: ${username}"

    local policies=(
        "ConstellationBootstrap"
        "ConstellationEphemeral"
        "ConstellationKubernetesOps"
    )

    for policy_name in "${policies[@]}"; do
        local policy_arn="arn:aws:iam::${account_id}:policy/${policy_name}"

        if aws iam list-attached-user-policies --user-name "${username}" | grep -q "${policy_name}"; then
            warn "Policy ${policy_name} already attached to ${username}"
        else
            aws iam attach-user-policy \
                --user-name "${username}" \
                --policy-arn "${policy_arn}"
            success "Attached policy: ${policy_name}"
        fi
    done
}

# Create access key
create_access_key() {
    local username=$1

    info "Creating access key for user: ${username}"

    # Check if user already has access keys
    local key_count
    key_count=$(aws iam list-access-keys --user-name "${username}" --query 'AccessKeyMetadata | length(@)' --output text)

    if [[ ${key_count} -ge 2 ]]; then
        warn "User ${username} already has 2 access keys (AWS maximum)"
        warn "Delete an existing key before creating a new one"
        return 0
    fi

    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠  IMPORTANT: Save these credentials - you won't see them again! ⚠${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local output
    output=$(aws iam create-access-key --user-name "${username}" --output json)

    local access_key_id
    local secret_access_key
    access_key_id=$(echo "${output}" | jq -r '.AccessKey.AccessKeyId')
    secret_access_key=$(echo "${output}" | jq -r '.AccessKey.SecretAccessKey')

    echo "AWS Access Key ID:     ${access_key_id}"
    echo "AWS Secret Access Key: ${secret_access_key}"
    echo ""
    echo -e "${BLUE}Store in 1Password or AWS Secrets Manager:${NC}"
    echo ""
    echo "  # Using 1Password CLI"
    echo "  op item create --category=login --title='${username}' \\"
    echo "    'username=${username}' \\"
    echo "    'AWS Access Key ID=${access_key_id}' \\"
    echo "    'AWS Secret Access Key=${secret_access_key}'"
    echo ""
    echo "  # Using AWS CLI profile"
    echo "  aws configure --profile constellation"
    echo "  # Enter: ${access_key_id}"
    echo "  # Enter: ${secret_access_key}"
    echo "  # Region: ${REGION}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Create MFA enforcement policy
create_mfa_policy() {
    local username=$1

    info "Creating MFA enforcement policy..."

    cat > /tmp/mfa-enforcement.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyAllExceptListedIfNoMFA",
      "Effect": "Deny",
      "NotAction": [
        "iam:CreateVirtualMFADevice",
        "iam:EnableMFADevice",
        "iam:GetUser",
        "iam:ListMFADevices",
        "iam:ListVirtualMFADevices",
        "iam:ResyncMFADevice",
        "sts:GetSessionToken"
      ],
      "Resource": "*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    }
  ]
}
EOF

    aws iam put-user-policy \
        --user-name "${username}" \
        --policy-name RequireMFA \
        --policy-document file:///tmp/mfa-enforcement.json

    rm /tmp/mfa-enforcement.json

    success "Created MFA enforcement policy"
    warn "User MUST enable MFA to use AWS services"
}

# Display next steps
display_next_steps() {
    local username=$1

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ IAM User Setup Complete${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo ""
    echo "1. Enable MFA for ${username} (REQUIRED)"
    echo "   - Go to AWS Console > IAM > Users > ${username} > Security credentials"
    echo "   - Assign MFA device (virtual or hardware)"
    echo ""
    echo "2. Configure AWS CLI with aws-vault (recommended):"
    echo "   brew install aws-vault"
    echo "   aws-vault add constellation"
    echo "   aws-vault exec constellation -- aws sts get-caller-identity"
    echo ""
    echo "3. Or configure standard AWS CLI profile:"
    echo "   aws configure --profile constellation"
    echo "   export AWS_PROFILE=constellation"
    echo ""
    echo "4. Test access:"
    echo "   aws sts get-caller-identity"
    echo "   aws s3 ls"
    echo ""
    echo "5. Deploy Carian Constellation:"
    echo "   cd ../blueprints/terraform/bootstrap"
    echo "   terraform init"
    echo "   terraform apply"
    echo ""
    echo -e "${YELLOW}⚠  Remember: MFA is required for all operations${NC}"
    echo ""
}

# Main execution
main() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}    Carian Constellation - IAM User Setup${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    check_prerequisites

    local account_id
    account_id=$(get_account_id)
    info "AWS Account ID: ${account_id}"

    # Confirm with user
    echo ""
    echo -e "${YELLOW}This will create:${NC}"
    echo "  - IAM user: ${USERNAME}"
    echo "  - 3 IAM policies (Bootstrap, Ephemeral, KubernetesOps)"
    echo "  - MFA enforcement policy"
    echo "  - Access key pair"
    echo ""
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warn "Aborted by user"
        exit 0
    fi

    create_user "${USERNAME}"
    create_policies "${account_id}"
    attach_policies "${USERNAME}" "${account_id}"
    create_access_key "${USERNAME}"
    create_mfa_policy "${USERNAME}"

    display_next_steps "${USERNAME}"
}

# Run main function
main "$@"
