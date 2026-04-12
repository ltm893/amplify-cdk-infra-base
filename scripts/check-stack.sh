#!/bin/bash
# check-stack.sh
# Check if the AmplifyInfraStack CloudFormation stack exists and show its details
#
# Usage:
#   chmod +x scripts/check-stack.sh
#   ./scripts/check-stack.sh

STACK_NAME="AmplifyInfraStack"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║        Check AWS Stack Status        ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  Stack: $STACK_NAME"
echo ""

STATUS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].StackStatus" \
  --output text 2>/dev/null)

if [[ -z "$STATUS" || "$STATUS" == "None" ]]; then
  echo "  ❌ No AWS resources found — stack '$STACK_NAME' does not exist."
  echo "     Run: npm install && npx cdk deploy"
  echo ""
  exit 0
fi

echo "  ✅ Stack found — Status: $STATUS"
echo ""
echo "  Outputs:"
echo "  ────────────────────────────────────────"

aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[].[OutputKey,OutputValue]" \
  --output text | while IFS=$'\t' read -r key value; do
    printf "  %-22s %s\n" "$key" "$value"
  done

echo ""
