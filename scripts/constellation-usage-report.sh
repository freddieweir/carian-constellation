#!/bin/bash
#
# Generate usage report from constellation-usage.log
#

USAGE_LOG="$HOME/.constellation-usage.log"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

if [ ! -f "$USAGE_LOG" ]; then
  echo -e "${RED}No usage log found at $USAGE_LOG${NC}"
  echo ""
  echo "The log will be created when you run:"
  echo "  ./scripts/constellation-up.sh"
  exit 1
fi

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Carian Constellation Usage Report                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Count deployments
total_deployments=$(grep -c " UP " "$USAGE_LOG" 2>/dev/null || echo "0")
echo -e "${GREEN}Total Deployments:${NC} $total_deployments"
echo ""

# Calculate total costs
total_cost=0
if command -v bc >/dev/null 2>&1; then
  while IFS= read -r line; do
    cost=$(echo "$line" | grep -oP 'cost=\$\K[0-9.]+' 2>/dev/null || echo "0")
    if [ -n "$cost" ] && [ "$cost" != "0" ]; then
      total_cost=$(echo "$total_cost + $cost" | bc)
    fi
  done < <(grep " DOWN " "$USAGE_LOG")

  echo -e "${GREEN}Total Estimated Cost:${NC} \$${total_cost}"
else
  echo -e "${YELLOW}Note: Install 'bc' for cost calculations${NC}"
fi
echo ""

# Recent activity
echo -e "${GREEN}Recent Activity (last 10 entries):${NC}"
echo "─────────────────────────────────────────────────────────────────"
tail -10 "$USAGE_LOG"
echo ""

# Monthly breakdown
if command -v bc >/dev/null 2>&1; then
  echo -e "${GREEN}Monthly Breakdown:${NC}"
  echo "─────────────────────────────────────────────────────────────────"
  awk -F'|' '
    /DOWN/ {
      month = substr($1, 1, 7);
      gsub(/cost=\$/, "", $4);
      gsub(/ /, "", $4);
      if ($4 > 0) {
        monthly[month] += $4;
      }
    }
    END {
      for (m in monthly) {
        printf "%s: $%.2f\n", m, monthly[m];
      }
    }
  ' "$USAGE_LOG" | sort
  echo ""
fi

# Check for currently running infrastructure
current_up=$(grep " UP " "$USAGE_LOG" 2>/dev/null | tail -1)
current_down=$(grep " DOWN " "$USAGE_LOG" 2>/dev/null | tail -1)

if [ -n "$current_up" ] && [ "$current_up" \> "$current_down" ]; then
  echo -e "${RED}⚠️  WARNING: Infrastructure may still be running!${NC}"
  echo "   Last UP:   $current_up"
  echo "   Last DOWN: ${current_down:-Never}"
  echo ""
  echo "   Verify with:"
  echo "   aws eks list-clusters --region us-west-2 --profile constellation-admin-vm"
else
  echo -e "${GREEN}✅ Infrastructure appears to be torn down${NC}"
fi
echo ""

# Calculate average session length
if command -v bc >/dev/null 2>&1 && [ "$total_deployments" -gt 0 ]; then
  total_hours=0
  count=0
  while IFS= read -r line; do
    hours=$(echo "$line" | grep -oP 'runtime=\K[0-9.]+' 2>/dev/null || echo "0")
    if [ -n "$hours" ] && [ "$hours" != "0" ]; then
      total_hours=$(echo "$total_hours + $hours" | bc)
      ((count++))
    fi
  done < <(grep " DOWN " "$USAGE_LOG")

  if [ "$count" -gt 0 ]; then
    avg_hours=$(echo "scale=2; $total_hours / $count" | bc)
    echo -e "${GREEN}Statistics:${NC}"
    echo "  Total Runtime: ${total_hours} hours"
    echo "  Average Session: ${avg_hours} hours"
    echo "  Sessions Completed: $count"
    echo ""
  fi
fi

# Show cost guidelines
echo -e "${GREEN}Budget Guidelines:${NC}"
echo "  ✅ Under 4 hours: Excellent (\$1 or less)"
echo "  ⚠️  4-8 hours: Acceptable (\$1-2)"
echo "  🚨 Over 8 hours: Review necessity (>\$2)"
echo "  ❌ Over 24 hours: Incident threshold (>\$6)"
echo ""

echo "─────────────────────────────────────────────────────────────────"
echo "For more details, view the log directly:"
echo "  cat $USAGE_LOG"
echo ""
