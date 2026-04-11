#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { DlivSetupStack } from "../lib/setup-stack";
import { config } from "./config";

// Generate a timestamp string: YYYYMMDDHHMI
const now       = new Date();
const dateStr   =
  String(now.getFullYear()) +
  String(now.getMonth() + 1).padStart(2, "0") +
  String(now.getDate()).padStart(2, "0") +
  String(now.getHours()).padStart(2, "0") +
  String(now.getMinutes()).padStart(2, "0");

const app = new cdk.App();

new DlivSetupStack(app, "DlivSetupStack", {
  publicBucketName:  `${config.id}-${dateStr}-public-bucket`,
  privateBucketName: `${config.id}-${dateStr}-private-bucket`,
  awsRegion:         config.awsRegion,
  userPoolName:      config.userPoolName,
  fromEmail:         config.fromEmail,
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region:  config.awsRegion,
  },
});
