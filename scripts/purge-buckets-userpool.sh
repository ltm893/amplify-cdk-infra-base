#!/bin/bash
# purge_buckets_userpool.sh
# Deletes the S3 buckets and Cognito User Pool that CDK retains after destroy.
#
# Resolves resource names in this order:
#   1. Live CloudFormation stack outputs  (stack still exists)
#   2. amplify_outputs.json              (stack destroyed, file present)
#   3. Manual prompt                      (neither available)
#
# Usage:
#   chmod +x scripts/purge_buckets_userpool.sh
#   ./scripts/purge_buckets_userpool.sh

set -e

STACK_NAME="AmplifyInfraStack"
REGION="us-east-1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUTS_FILE="$ROOT_DIR/amplify_outputs.json"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║     Cleanup Retained AWS Resources   ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── Helper: pull one value from CloudFormation outputs ───────────────────────
cf_output() {
  aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" \
    --output text 2>/dev/null || echo ""
}

# ── 1. Try CloudFormation ─────────────────────────────────────────────────────
echo "  Looking up resource names ..."

PUBLIC_BUCKET=$(cf_output "PublicBucketName")
PRIVATE_BUCKET=$(cf_output "PrivateBucketName")
USER_POOL_ID=$(cf_output "UserPoolId")

# ── 2. Fall back to amplify_outputs.json ─────────────────────────────────────
if [[ -z "$PUBLIC_BUCKET" && -f "$OUTPUTS_FILE" ]]; then
  echo "  ⚠️  Stack not found — reading from amplify_outputs.json ..."
  PUBLIC_BUCKET=$(python3 -c "
import json, sys
d = json.load(open('$OUTPUTS_FILE'))
buckets = d.get('storage', {}).get('buckets', [])
pub = next((b['bucket_name'] for b in buckets if b['name'] == 'public'), '')
print(pub)
" 2>/dev/null || echo "")

  PRIVATE_BUCKET=$(python3 -c "
import json, sys
d = json.load(open('$OUTPUTS_FILE'))
buckets = d.get('storage', {}).get('buckets', [])
priv = next((b['bucket_name'] for b in buckets if b['name'] == 'private'), '')
print(priv)
" 2>/dev/null || echo "")

  USER_POOL_ID=$(python3 -c "
import json
d = json.load(open('$OUTPUTS_FILE'))
print(d.get('auth', {}).get('user_pool_id', ''))
" 2>/dev/null || echo "")
fi

# ── 3. Fall back to manual prompt ─────────────────────────────────────────────
if [[ -z "$PUBLIC_BUCKET" ]]; then
  echo "  ⚠️  Could not resolve names automatically."
  echo "      (Stack gone and no amplify_outputs.json found)"
  echo ""
  read -p "  Public bucket name  : " PUBLIC_BUCKET
  read -p "  Private bucket name : " PRIVATE_BUCKET
  read -p "  User Pool ID        : " USER_POOL_ID
fi

# ── Confirm ───────────────────────────────────────────────────────────────────
echo ""
echo "  Resources to delete:"
echo "    Public bucket  : $PUBLIC_BUCKET"
echo "    Private bucket : $PRIVATE_BUCKET"
echo "    User Pool ID   : $USER_POOL_ID"
echo ""
echo "  ⚠️  This is PERMANENT. These cannot be recovered."
echo ""
read -p "  Type 'delete' to confirm: " CONFIRM
if [[ "$CONFIRM" != "delete" ]]; then
  echo ""
  echo "  Cancelled."
  echo ""
  exit 0
fi

echo ""

# ── Delete public bucket ──────────────────────────────────────────────────────
echo "  Deleting public bucket: $PUBLIC_BUCKET ..."
if aws s3api head-bucket --bucket "$PUBLIC_BUCKET" --region "$REGION" 2>/dev/null; then
  aws s3 rm "s3://$PUBLIC_BUCKET" --recursive --region "$REGION"
  aws s3api delete-bucket --bucket "$PUBLIC_BUCKET" --region "$REGION"
  echo "  ✅ Public bucket deleted"
else
  echo "  ⏭️  Public bucket not found — skipping"
fi

# ── Delete private bucket (versioned) ────────────────────────────────────────
echo ""
echo "  Deleting private bucket (versioned): $PRIVATE_BUCKET ..."
if aws s3api head-bucket --bucket "$PRIVATE_BUCKET" --region "$REGION" 2>/dev/null; then

  aws s3api list-object-versions \
    --bucket "$PRIVATE_BUCKET" \
    --region "$REGION" \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json | \
  python3 -c "
import json, sys, subprocess
data = json.load(sys.stdin)
objects = data.get('Objects') or []
if not objects:
    sys.exit(0)
payload = json.dumps({'Objects': objects, 'Quiet': True})
subprocess.run(['aws', 's3api', 'delete-objects',
    '--bucket', '$PRIVATE_BUCKET', '--region', '$REGION',
    '--delete', payload], check=True)
print(f'  Deleted {len(objects)} version(s).')
"

  aws s3api list-object-versions \
    --bucket "$PRIVATE_BUCKET" \
    --region "$REGION" \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
    --output json | \
  python3 -c "
import json, sys, subprocess
data = json.load(sys.stdin)
objects = data.get('Objects') or []
if not objects:
    sys.exit(0)
payload = json.dumps({'Objects': objects, 'Quiet': True})
subprocess.run(['aws', 's3api', 'delete-objects',
    '--bucket', '$PRIVATE_BUCKET', '--region', '$REGION',
    '--delete', payload], check=True)
print(f'  Deleted {len(objects)} delete marker(s).')
"

  aws s3api delete-bucket --bucket "$PRIVATE_BUCKET" --region "$REGION"
  echo "  ✅ Private bucket deleted"
else
  echo "  ⏭️  Private bucket not found — skipping"
fi

# ── Delete Cognito User Pool ──────────────────────────────────────────────────
echo ""
echo "  Deleting Cognito User Pool: $USER_POOL_ID ..."
if aws cognito-idp describe-user-pool \
  --user-pool-id "$USER_POOL_ID" \
  --region "$REGION" > /dev/null 2>&1; then

  CLIENTS=$(aws cognito-idp list-user-pool-clients \
    --user-pool-id "$USER_POOL_ID" \
    --region "$REGION" \
    --query "UserPoolClients[].ClientId" \
    --output text)

  for CLIENT_ID in $CLIENTS; do
    aws cognito-idp delete-user-pool-client \
      --user-pool-id "$USER_POOL_ID" \
      --client-id "$CLIENT_ID" \
      --region "$REGION"
    echo "  Deleted app client: $CLIENT_ID"
  done

  aws cognito-idp delete-user-pool \
    --user-pool-id "$USER_POOL_ID" \
    --region "$REGION"
  echo "  ✅ Cognito User Pool deleted"
else
  echo "  ⏭️  User Pool not found — skipping"
fi

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       All retained resources gone    ║"
echo "╚══════════════════════════════════════╝"
echo ""
