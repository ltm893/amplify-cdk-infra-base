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

### 3. Create your config file

```bash
cp bin/config.example.ts bin/config.ts
```

Open `bin/config.ts` and fill in your values:

```ts
export const config = {
  id:           "yourname",         // used as a prefix on bucket names
  awsRegion:    "us-east-1",        // AWS region to deploy into
  userPoolName: "yourname-app-users",
  fromEmail:    "noreply@yourdomain.com",
};
```

> `bin/config.ts` is in `.gitignore` — your personal values will never be committed.

### 4. Bootstrap CDK (first time only)

If you have never used CDK in your AWS account before, run this once:

```bash
npx cdk bootstrap
```

### 5. Deploy

```bash
npx cdk deploy
```

You will be asked to approve a security change (the public S3 bucket policy). Type `y` and press Enter.

---

## After deploying

The terminal will print output values like this:

```
PublicBucketName  = yourname-202604111059-public-bucket
PrivateBucketName = yourname-202604111059-private-bucket
UserPoolId        = us-east-1_AbCdEfGh
UserPoolClientId  = abc123xyz
```

Copy these into your app's `amplify_outputs.json`.

---

## Tearing down

If you want to remove the CloudFormation stack (note: buckets and user pool are set to RETAIN and will not be deleted automatically):

```bash
npx cdk destroy
```

To fully clean up, delete the S3 buckets and Cognito User Pool manually in the AWS Console.
