# amplify-cdk-infra-base

A CDK stack that provisions the AWS infrastructure needed to run an Amplify web app — two S3 buckets, a Cognito User Pool, a Cognito Identity Pool, and an authenticated IAM role with full CRUD access to both buckets.

## What gets created

| Resource | Purpose |
|---|---|
| Public S3 bucket | Stores photos / slideshow content (publicly readable, authenticated CRUD) |
| Private S3 bucket | Stores private files for authenticated users only (full CRUD) |
| Cognito User Pool | Invite-only authentication (you add users manually) |
| Cognito Identity Pool | Converts User Pool logins into temporary AWS credentials for S3 access |
| IAM Authenticated Role | Grants signed-in users GetObject, PutObject, DeleteObject, ListBucket on both buckets |

---

## Prerequisites

You need the following installed on your machine:

- [Node.js](https://nodejs.org/) (v18 or later) — required for CDK and npx
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- [Python 3](https://www.python.org/) (for CRUD tests)
- An AWS account with credentials configured

### Configure your AWS credentials

If you haven't done this before, run:

```bash
aws configure
```

You'll be prompted for your AWS Access Key ID, Secret Access Key, and region. Get these from your AWS account under **IAM → Users → Security credentials**.

---

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/amplify-cdk-infra-base.git
cd amplify-cdk-infra-base
```

### 2. Install dependencies

```bash
npm install
```

### 3. Make all scripts executable

```bash
chmod +x scripts/*.sh
```

### 4. Deploy

```bash
./scripts/deploy.sh
```

The script will prompt you for:
- **ID/username** — used as a prefix on bucket names (automatically lowercased)
- **AWS region** — defaults to `us-east-1`
- **Cognito User Pool name** — defaults to `yourid-app-users`
- **From email** — address Cognito sends invite emails from

After confirming, it:
1. Generates `bin/config.ts`
2. Runs `cdk deploy`
3. Pulls all stack outputs from CloudFormation
4. Auto-generates `amplify_outputs.json` in the project root

> You will be asked to approve a security change (the public S3 bucket policy). Type `y` and press Enter.

---

## After deploying

`amplify_outputs.json` is automatically written to the project root with all resource IDs from the deployment:

```json
{
  "version": "1",
  "storage": {
    "aws_region": "us-east-1",
    "buckets": [
      { "name": "public",  "bucket_name": "yourname-...-public-bucket",  "aws_region": "us-east-1" },
      { "name": "private", "bucket_name": "yourname-...-private-bucket", "aws_region": "us-east-1" }
    ]
  },
  "auth": {
    "user_pool_id": "us-east-1_...",
    "user_pool_client_id": "...",
    "identity_pool_id": "us-east-1:..."
  }
}
```

---

## Check stack status

At any time you can check whether your stack is deployed and see all resource IDs:

```bash
./scripts/check-stack.sh
```

---

## Test CRUD operations

After deploying, run the full Create / Read / Update / Delete test against both S3 buckets:

```bash
./scripts/setup-venv-test-crud.sh
```

This will:
1. Create a Python virtual environment at `.venv/` (first run only)
2. Install `boto3` into the venv
3. Pull bucket names live from CloudFormation
4. Run a full CRUD cycle (Create → Read → Update → Delete) against both the public and private buckets
5. Print ✅ PASS or ❌ FAIL for each step

On subsequent runs the venv is reused — no reinstall needed.

To run the test directly after the venv exists:

```bash
.venv/bin/python3 scripts/test-crud.py
```

---

## Add a user

To invite someone to your Cognito User Pool (they will receive an email with a temporary password):

```bash
./scripts/create-cognito-user.sh
```

The script looks up your User Pool ID automatically from the deployed stack.

---

## Tearing down

### Step 1 — Destroy the CloudFormation stack

```bash
./scripts/destroy.sh
```

This removes the Identity Pool and IAM role. The S3 buckets and Cognito User Pool are set to **RETAIN** and survive this step intentionally.

### Step 2 — Delete the retained resources

```bash
./scripts/purge-buckets-userpool.sh
```

This deletes the two S3 buckets and the Cognito User Pool permanently. Resource names are resolved in this order:

1. Live CloudFormation outputs (if the stack still exists)
2. `amplify_outputs.json` (if the stack is already destroyed)
3. Manual prompt (if neither is available)

> ⚠️ This is permanent and cannot be undone.

---

## Scripts reference

| Script | Purpose |
|---|---|
| `scripts/deploy.sh` | Prompt for config, deploy stack, generate `amplify_outputs.json` |
| `scripts/check-stack.sh` | Check stack status and show all resource IDs |
| `scripts/setup-venv-test-crud.sh` | Create Python venv, install boto3, run CRUD tests |
| `scripts/create-cognito-user.sh` | Invite a new user to the Cognito User Pool |
| `scripts/destroy.sh` | Tear down the CloudFormation stack |
| `scripts/purge-buckets-userpool.sh` | Permanently delete retained S3 buckets and User Pool |
