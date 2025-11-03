#!/bin/bash
#
# Setup AWS Budget for Carian Constellation
# Creates monthly $15 budget with alerts at $10 (66%) and $15 (100%)

set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-constellation-admin-vm}"
AWS_REGION="us-east-1"  # Budgets API only in us-east-1
ACCOUNT_ID="659093129022"
SNS_TOPIC_ARN="arn:aws:sns:us-east-1:659093129022:constellation-billing-alerts"

export AWS_PROFILE

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
  echo -e "${GREEN}[$(date -Iseconds)]${NC} $*"
}

warn() {
  echo -e "${YELLOW}[$(date -Iseconds)]${NC} $*"
}

# Get current month start date
START_DATE=$(date +%Y-%m-01)

# Create budget configuration
cat > /tmp/budget-config.json << EOF
{
  "BudgetName": "constellation-monthly-budget",
  "BudgetLimit": {
    "Amount": "15.00",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST",
  "CostTypes": {
    "IncludeTax": true,
    "IncludeSubscription": true,
    "UseBlended": false,
    "IncludeRefund": false,
    "IncludeCredit": false,
    "IncludeUpfront": true,
    "IncludeRecurring": true,
    "IncludeOtherSubscription": true,
    "IncludeSupport": true,
    "IncludeDiscount": true,
    "UseAmortized": false
  },
  "TimePeriod": {
    "Start": "${START_DATE}T00:00:00Z"
  }
}
EOF

# Create notification subscribers
cat > /tmp/budget-notifications.json << EOF
[
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 66.0,
      "ThresholdType": "PERCENTAGE",
      "NotificationState": "ALARM"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "aws@freddieweir.com"
      },
      {
        "SubscriptionType": "SNS",
        "Address": "$SNS_TOPIC_ARN"
      }
    ]
  },
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 100.0,
      "ThresholdType": "PERCENTAGE",
      "NotificationState": "ALARM"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "aws@freddieweir.com"
      },
      {
        "SubscriptionType": "SNS",
        "Address": "$SNS_TOPIC_ARN"
      }
    ]
  },
  {
    "Notification": {
      "NotificationType": "FORECASTED",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 100.0,
      "ThresholdType": "PERCENTAGE",
      "NotificationState": "ALARM"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "aws@freddieweir.com"
      }
    ]
  }
]
EOF

log "Creating AWS Budget for Carian Constellation..."
log "Account ID: $ACCOUNT_ID"
log "Budget Limit: \$15/month"
log "Alerts at: 66% (\$10) and 100% (\$15)"
echo ""

# Check if budget already exists
existing_budget=$(aws budgets describe-budgets \
  --account-id "$ACCOUNT_ID" \
  --region "$AWS_REGION" \
  --query "Budgets[?BudgetName=='constellation-monthly-budget'].BudgetName" \
  --output text 2>/dev/null || echo "")

if [ -n "$existing_budget" ]; then
  warn "Budget 'constellation-monthly-budget' already exists"
  warn "Skipping creation. To update, delete and recreate:"
  echo "  aws budgets delete-budget --account-id $ACCOUNT_ID --budget-name constellation-monthly-budget --region $AWS_REGION --profile $AWS_PROFILE"
  echo ""
else
  # Create budget
  if aws budgets create-budget \
    --account-id "$ACCOUNT_ID" \
    --budget file:///tmp/budget-config.json \
    --notifications-with-subscribers file:///tmp/budget-notifications.json \
    --region "$AWS_REGION" 2>/dev/null; then

    log "✅ Budget created successfully"
  else
    warn "Budget creation may have failed. Checking if it exists..."
    if aws budgets describe-budgets \
      --account-id "$ACCOUNT_ID" \
      --region "$AWS_REGION" \
      --query "Budgets[?BudgetName=='constellation-monthly-budget']" 2>/dev/null | grep -q "constellation-monthly-budget"; then
      log "✅ Budget exists (may have been created previously)"
    else
      echo "❌ Budget creation failed"
      echo "Check IAM permissions for budgets:CreateBudget"
      exit 1
    fi
  fi
fi

echo ""
log "Budget Details:"
echo "  Name: constellation-monthly-budget"
echo "  Limit: \$15/month"
echo "  Alerts:"
echo "    - 66% (\$10): Warning email + SNS"
echo "    - 100% (\$15): Critical email + SNS"
echo "    - 100% forecast: Predictive email"
echo ""
log "Verify at: https://console.aws.amazon.com/billing/home#/budgets"
echo ""

# Cleanup temp files
rm -f /tmp/budget-config.json /tmp/budget-notifications.json

log "Setup complete!"
