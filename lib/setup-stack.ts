import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";
import * as s3 from "aws-cdk-lib/aws-s3";
import * as cognito from "aws-cdk-lib/aws-cognito";
import * as iam from "aws-cdk-lib/aws-iam";

export interface AmplifyInfraStackProps extends cdk.StackProps {
  publicBucketName:  string;
  privateBucketName: string;
  awsRegion:         string;
  userPoolName:      string;
  fromEmail:         string;
}

export class AmplifyInfraStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: AmplifyInfraStackProps) {
    super(scope, id, props);

    // ── Public S3 Bucket (publicly readable, authenticated CRUD) ─────────────
    const publicBucket = new s3.Bucket(this, "PublicBucket", {
      bucketName:        props.publicBucketName,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ACLS,
      publicReadAccess:  false,
      versioned:         false,
      removalPolicy:     cdk.RemovalPolicy.RETAIN,
      cors: [
        {
          allowedOrigins: ["*"],
          allowedMethods: [
            s3.HttpMethods.GET,
            s3.HttpMethods.HEAD,
            s3.HttpMethods.PUT,
            s3.HttpMethods.DELETE,
          ],
          allowedHeaders: ["*"],
          exposedHeaders: ["ETag"],
          maxAge:         3000,
        },
      ],
    });

    // Anyone can GET objects (photos are public)
    publicBucket.addToResourcePolicy(
      new iam.PolicyStatement({
        sid:        "PublicReadGetObject",
        effect:     iam.Effect.ALLOW,
        principals: [new iam.AnyPrincipal()],
        actions:    ["s3:GetObject"],
        resources:  [`${publicBucket.bucketArn}/*`],
      })
    );

    // ── Private S3 Bucket (authenticated users only) ─────────────────────────
    const privateBucket = new s3.Bucket(this, "PrivateBucket", {
      bucketName:        props.privateBucketName,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      versioned:         true,
      removalPolicy:     cdk.RemovalPolicy.RETAIN,
      cors: [
        {
          allowedOrigins: ["*"],
          allowedMethods: [
            s3.HttpMethods.GET,
            s3.HttpMethods.PUT,
            s3.HttpMethods.DELETE,
            s3.HttpMethods.HEAD,
          ],
          allowedHeaders: ["*"],
          exposedHeaders: ["ETag"],
          maxAge:         3000,
        },
      ],
    });

    // ── Cognito User Pool (invite-only) ──────────────────────────────────────
    const userPool = new cognito.UserPool(this, "UserPool", {
      userPoolName:      props.userPoolName,
      selfSignUpEnabled: false,
      signInAliases:     { email: true },
      autoVerify:        { email: true },

      userInvitation: {
        emailSubject: "Your invite to the app",
        emailBody:
          "Hi {username}, you have been invited.<br/>" +
          "Your temporary password is: <strong>{####}</strong><br/>" +
          "You will be asked to set a new password on first sign in.",
      },

      passwordPolicy: {
        minLength:        8,
        requireLowercase: true,
        requireUppercase: true,
        requireDigits:    true,
        requireSymbols:   true,
      },

      accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
      removalPolicy:   cdk.RemovalPolicy.RETAIN,
    });

    const userPoolClient = userPool.addClient("WebClient", {
      userPoolClientName:         "web-client",
      authFlows: {
        userPassword:             true,
        userSrp:                  true,
        adminUserPassword:        true,
      },
      preventUserExistenceErrors: true,
    });

    // ── Cognito Identity Pool ─────────────────────────────────────────────────
    const identityPool = new cognito.CfnIdentityPool(this, "IdentityPool", {
      identityPoolName:               `${props.userPoolName.replace(/-/g, "_")}_identity_pool`,
      allowUnauthenticatedIdentities: false,
      cognitoIdentityProviders: [
        {
          clientId:     userPoolClient.userPoolClientId,
          providerName: userPool.userPoolProviderName,
        },
      ],
    });

    // ── IAM Role for Authenticated Users ─────────────────────────────────────
    const authenticatedRole = new iam.Role(this, "CognitoAuthenticatedRole", {
      description: "Role assumed by Cognito Identity Pool authenticated users",
      assumedBy: new iam.FederatedPrincipal(
        "cognito-identity.amazonaws.com",
        {
          StringEquals: {
            "cognito-identity.amazonaws.com:aud": identityPool.ref,
          },
          "ForAnyValue:StringLike": {
            "cognito-identity.amazonaws.com:amr": "authenticated",
          },
        },
        "sts:AssumeRoleWithWebIdentity"
      ),
    });

    authenticatedRole.addToPolicy(
      new iam.PolicyStatement({
        sid:       "PublicBucketCRUD",
        effect:    iam.Effect.ALLOW,
        actions:   ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
        resources: [`${publicBucket.bucketArn}/*`],
      })
    );

    authenticatedRole.addToPolicy(
      new iam.PolicyStatement({
        sid:       "PublicBucketList",
        effect:    iam.Effect.ALLOW,
        actions:   ["s3:ListBucket"],
        resources: [publicBucket.bucketArn],
      })
    );

    authenticatedRole.addToPolicy(
      new iam.PolicyStatement({
        sid:       "PrivateBucketCRUD",
        effect:    iam.Effect.ALLOW,
        actions:   ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
        resources: [`${privateBucket.bucketArn}/*`],
      })
    );

    authenticatedRole.addToPolicy(
      new iam.PolicyStatement({
        sid:       "PrivateBucketList",
        effect:    iam.Effect.ALLOW,
        actions:   ["s3:ListBucket"],
        resources: [privateBucket.bucketArn],
      })
    );

    // ── Attach Role to Identity Pool ─────────────────────────────────────────
    new cognito.CfnIdentityPoolRoleAttachment(this, "IdentityPoolRoleAttachment", {
      identityPoolId: identityPool.ref,
      roles: {
        authenticated: authenticatedRole.roleArn,
      },
    });

    // ── Outputs ──────────────────────────────────────────────────────────────
    new cdk.CfnOutput(this, "PublicBucketName",     { value: publicBucket.bucketName,            description: "Public S3 bucket name" });
    new cdk.CfnOutput(this, "PrivateBucketName",    { value: privateBucket.bucketName,           description: "Private S3 bucket name" });
    new cdk.CfnOutput(this, "S3RegionUrl",          { value: `https://s3.${props.awsRegion}.amazonaws.com/`, description: "S3 region URL" });
    new cdk.CfnOutput(this, "UserPoolId",           { value: userPool.userPoolId,                description: "Cognito User Pool ID" });
    new cdk.CfnOutput(this, "UserPoolClientId",     { value: userPoolClient.userPoolClientId,    description: "Cognito App Client ID" });
    new cdk.CfnOutput(this, "IdentityPoolId",       { value: identityPool.ref,                   description: "Cognito Identity Pool ID" });
    new cdk.CfnOutput(this, "AuthenticatedRoleArn", { value: authenticatedRole.roleArn,          description: "IAM role ARN for authenticated users" });
  }
}
