#!/bin/bash
# create-cognito-user.sh
# Creates an invite-only Cognito user and sends them a temporary password via email
#
# Usage:
#   chmod +x scripts/create-cognito-user.sh
#   ./scripts/create-cognito-user.sh

set -e

STACK_NAME="AmplifyInfraStack"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║        Create Cognito User           ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  Looking up User Pool ID from CloudFormation stack: $STACK_NAME ..."
echo ""

# Query CloudFormation for the User Pool ID output
USER_POOL_ID=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='UserPoolId'].OutputValue" \
  --output text 2>/dev/null)

if [[ -z "$USER_POOL_ID" || "$USER_POOL_ID" == "None" ]]; then
  echo "⚠️   Could not find stack '$STACK_NAME' or UserPoolId output."
  echo "    Make sure you have run: npx cdk deploy"
  echo ""
  read -p "  Enter User Pool ID manually (e.g. us-east-1_AbCdEfGh): " USER_POOL_ID
  if [[ -z "$USER_POOL_ID" ]]; then
    echo "❌  User Pool ID cannot be empty."
    exit 1
  fi
else
  echo "  ✅ Found User Pool ID: $USER_POOL_ID"
fi

# Extract region from User Pool ID (everything before the underscore)
AWS_REGION=$(echo "$USER_POOL_ID" | cut -d'_' -f1)

# Prompt for user email
read -p "  Enter user email address: " USER_EMAIL

if [[ -z "$USER_EMAIL" ]]; then
  echo "❌  Email cannot be empty."
  exit 1
fi

echo ""
echo "  Creating user: $USER_EMAIL"
echo "  User Pool:     $USER_POOL_ID"
echo "  Region:        $AWS_REGION"
echo ""

# Create the user — Cognito sends a temporary password to their email
aws cognito-idp admin-create-user \
  --region "$AWS_REGION" \
  --user-pool-id "$USER_POOL_ID" \
  --username "$USER_EMAIL" \
  --user-attributes Name=email,Value="$USER_EMAIL" Name=email_verified,Value=true \
  --desired-delivery-mediums EMAIL

echo ""
echo "✅  Done! $USER_EMAIL will receive an invite email with a temporary password."
echo "    They will be prompted to set a new password on first sign in."
echo ""
