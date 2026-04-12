# amplify-cdk-infra-base

A CDK stack that provisions the AWS infrastructure needed to run an Amplify web app — two S3 buckets and a Cognito User Pool. Designed to be simple enough for frontend developers who are new to AWS.

## What gets created

| Resource | Purpose |
|---|---|
| Public S3 bucket | Stores photos / slideshow content (publicly readable) |
| Private S3 bucket | Stores private files for authenticated users only |
| Cognito User Pool | Invite-only authentication (you add users manually) |

---

## Prerequisites

You need the following installed on your machine:

- [Node.js](https://nodejs.org/) (v18 or later)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
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

### 3. Deploy

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

The script will prompt you for:
- **ID/username** — used as a prefix on bucket names (automatically lowercased)
- **AWS region** — defaults to `us-east-1`
- **Cognito User Pool name** — defaults to `yourid-app-users`
- **From email** — address Cognito sends invite emails from

After confirming, it generates `bin/config.ts`, runs `cdk deploy`, and automatically verifies the deployment.

> You will be asked to approve a security change (the public S3 bucket policy). Type `y` and press Enter.

---

## After deploying

The terminal will print output values like this:

```
PublicBucketName  = yourname-202604120947-public-bucket
PrivateBucketName = yourname-202604120947-private-bucket
UserPoolId        = us-east-1_AbCdEfGh
UserPoolClientId  = abc123xyz
```

Copy these into your app's `amplify_outputs.json`.

---

## Check stack status

At any time you can check whether your stack is deployed and see all resource IDs:

```bash
chmod +x scripts/check-stack.sh
./scripts/check-stack.sh
```

---

## Add a user

To invite someone to your Cognito User Pool (they will receive an email with a temporary password):

```bash
chmod +x scripts/create-cognito-user.sh
./scripts/create-cognito-user.sh
```

The script looks up your User Pool ID automatically from the deployed stack.

---

## Tearing down

To remove the CloudFormation stack:

```bash
chmod +x scripts/destroy.sh
./scripts/destroy.sh
```

> ⚠️ S3 buckets and Cognito User Pool are set to **RETAIN** and will not be deleted automatically. You must remove those manually in the AWS Console if needed.

---

## Scripts reference

| Script | Purpose |
|---|---|
| `scripts/deploy.sh` | Prompt for config, deploy stack, verify |
| `scripts/check-stack.sh` | Check stack status and show all resource IDs |
| `scripts/create-cognito-user.sh` | Invite a new user to the Cognito User Pool |
| `scripts/destroy.sh` | Tear down the CloudFormation stack and verify |
