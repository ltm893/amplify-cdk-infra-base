// ── HOW TO USE ────────────────────────────────────────────────────────────────
// 1. Copy this file:  cp bin/config.example.ts bin/config.ts
// 2. Fill in your values below
// 3. Run: npm install && npx cdk deploy
// config.ts is in .gitignore so your personal values are never committed
// ─────────────────────────────────────────────────────────────────────────────

export const config = {
  // Your name or GitHub username — used as a prefix to make bucket names unique
  id:               "yourname",

  // AWS region to deploy into
  awsRegion:        "us-east-1",

  // Cognito User Pool display name (does not need to be unique)
  userPoolName:     "yourname-app-users",

  // Email address Cognito sends invite emails from
  // Must be verified in AWS SES for production use
  fromEmail:        "noreply@yourdomain.com",
};
