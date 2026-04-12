#!/bin/bash
# destroy.sh
# Tears down the AmplifyInfraStack CloudFormation stack
# Note: S3 buckets and Cognito User Pool are set to RETAIN and must be deleted manually
#
# Usage:
#   chmod +x scripts/destroy.sh
#   ./scripts/destroy.sh

set -e

STACK_NAME="AmplifyInfraStack"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       Amplify CDK Infra Destroy      ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  ⚠️  This will delete the CloudFormation stack: $STACK_NAME"
echo "  ⚠️  S3 buckets and Cognito User Pool will NOT be deleted automatically."
echo "      You must remove those manually in the AWS Console if needed."
echo ""

read -p "  Are you sure you want to destroy the stack? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo ""
  echo "  Cancelled."
  echo ""
  exit 0
fi

echo ""
echo "  Running cdk destroy ..."
echo ""
npx cdk destroy --force

# ── Verify ────────────────────────────────────────────────────────────────────

echo ""
echo "  Verifying teardown ..."
echo ""
bash scripts/check-stack.sh
