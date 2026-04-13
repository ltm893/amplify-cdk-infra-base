#!/usr/bin/env python3
"""
test-crud.py
────────────
CRUD tests for the public and private S3 buckets deployed by AmplifyInfraStack.

Uses your default AWS CLI credentials (same as cdk deploy).
No Cognito login needed — this tests bucket access directly via IAM.

Usage:
    python3 scripts/test-crud.py
    python3 scripts/test-crud.py --stack AmplifyInfraStack --region us-east-1
"""

import argparse
import sys
import time
import boto3
from botocore.exceptions import ClientError

# ── Colour helpers ────────────────────────────────────────────────────────────
GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
BOLD   = "\033[1m"
RESET  = "\033[0m"

def ok(msg):   print(f"  {GREEN}✅ PASS{RESET}  {msg}")
def fail(msg): print(f"  {RED}❌ FAIL{RESET}  {msg}"); sys.exit(1)
def info(msg): print(f"  {CYAN}ℹ️  {msg}{RESET}")
def header(msg): print(f"\n{BOLD}{YELLOW}{msg}{RESET}")

# ── CloudFormation helpers ────────────────────────────────────────────────────
def get_stack_outputs(stack_name: str, region: str) -> dict:
    """Return all CloudFormation stack outputs as a plain dict."""
    cf = boto3.client("cloudformation", region_name=region)
    try:
        stacks = cf.describe_stacks(StackName=stack_name)["Stacks"]
    except ClientError as e:
        print(f"\n{RED}Could not find stack '{stack_name}': {e}{RESET}")
        print("Run 'npx cdk deploy' first, then retry.\n")
        sys.exit(1)

    return {o["OutputKey"]: o["OutputValue"] for o in stacks[0].get("Outputs", [])}

# ── CRUD test suite ───────────────────────────────────────────────────────────
def run_crud(bucket_name: str, label: str, s3, public: bool = False):
    """
    Run a full Create → Read → Update → Delete cycle against `bucket_name`.

    Steps
    -----
    1. CREATE  – upload a freshly created test file
    2. READ    – download it and verify the content matches
    3. UPDATE  – overwrite with new content, re-read and verify
    4. DELETE  – delete the object, confirm it's gone
    """
    key          = f"crud-test/{int(time.time())}-test.txt"
    original_txt = "CRUD test — original content"
    updated_txt  = "CRUD test — UPDATED content"

    header(f"Testing {label}  →  s3://{bucket_name}")
    info(f"Key: {key}")

    # ── 1. CREATE (PutObject) ─────────────────────────────────────────────────
    print(f"\n  {BOLD}1. CREATE{RESET}")
    try:
        s3.put_object(Bucket=bucket_name, Key=key, Body=original_txt.encode())
        ok(f"PutObject succeeded")
    except ClientError as e:
        fail(f"PutObject failed: {e}")

    # ── 2. READ (GetObject) ───────────────────────────────────────────────────
    print(f"\n  {BOLD}2. READ{RESET}")
    try:
        response = s3.get_object(Bucket=bucket_name, Key=key)
        body     = response["Body"].read().decode()
        if body == original_txt:
            ok(f"GetObject content matches → '{body}'")
        else:
            fail(f"Content mismatch — expected '{original_txt}', got '{body}'")
    except ClientError as e:
        fail(f"GetObject failed: {e}")

    # ── 3. UPDATE (PutObject overwrite, then re-read) ─────────────────────────
    print(f"\n  {BOLD}3. UPDATE{RESET}")
    try:
        s3.put_object(Bucket=bucket_name, Key=key, Body=updated_txt.encode())
        ok("PutObject (overwrite) succeeded")
    except ClientError as e:
        fail(f"Update PutObject failed: {e}")

    try:
        body = s3.get_object(Bucket=bucket_name, Key=key)["Body"].read().decode()
        if body == updated_txt:
            ok(f"Re-read after update matches → '{body}'")
        else:
            fail(f"Update content mismatch — expected '{updated_txt}', got '{body}'")
    except ClientError as e:
        fail(f"Re-read after update failed: {e}")

    # ── 4. DELETE (DeleteObject + verify gone) ────────────────────────────────
    print(f"\n  {BOLD}4. DELETE{RESET}")
    try:
        s3.delete_object(Bucket=bucket_name, Key=key)
        ok("DeleteObject succeeded")
    except ClientError as e:
        fail(f"DeleteObject failed: {e}")

    # Verify the object is actually gone
    try:
        s3.head_object(Bucket=bucket_name, Key=key)
        fail("Object still exists after DeleteObject — expected 404")
    except ClientError as e:
        code = e.response["Error"]["Code"]
        if code in ("404", "NoSuchKey"):
            ok("Object confirmed deleted (404 on HeadObject)")
        else:
            fail(f"Unexpected error checking deletion: {e}")

    print(f"\n  {GREEN}{BOLD}All CRUD operations passed for {label}{RESET}\n")

# ── List bucket ───────────────────────────────────────────────────────────────
def check_list(bucket_name: str, label: str, s3):
    """Confirm ListBucket works (required for UI file browsers)."""
    print(f"  {BOLD}ListBucket{RESET}")
    try:
        resp = s3.list_objects_v2(Bucket=bucket_name, MaxKeys=5)
        count = resp.get("KeyCount", 0)
        ok(f"ListBucket succeeded — {count} object(s) visible")
    except ClientError as e:
        fail(f"ListBucket failed: {e}")

# ── Entry point ───────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="CRUD test for AmplifyInfraStack S3 buckets")
    parser.add_argument("--stack",  default="AmplifyInfraStack", help="CloudFormation stack name")
    parser.add_argument("--region", default="us-east-1",         help="AWS region")
    args = parser.parse_args()

    print(f"\n{BOLD}{'═' * 52}")
    print(f"  S3 CRUD Test  —  stack: {args.stack}")
    print(f"{'═' * 52}{RESET}")

    # Pull bucket names straight from the stack outputs
    outputs      = get_stack_outputs(args.stack, args.region)
    public_name  = outputs.get("PublicBucketName")
    private_name = outputs.get("PrivateBucketName")

    if not public_name or not private_name:
        print(f"{RED}Could not find PublicBucketName / PrivateBucketName in stack outputs.{RESET}")
        print("Available outputs:", list(outputs.keys()))
        sys.exit(1)

    info(f"Public  bucket : {public_name}")
    info(f"Private bucket : {private_name}")

    s3 = boto3.client("s3", region_name=args.region)

    # ── Public bucket ─────────────────────────────────────────────────────────
    header("── Public Bucket ──────────────────────────────────")
    check_list(public_name, "Public", s3)
    run_crud(public_name, "Public Bucket", s3, public=True)

    # ── Private bucket ────────────────────────────────────────────────────────
    header("── Private Bucket ─────────────────────────────────")
    check_list(private_name, "Private", s3)
    run_crud(private_name, "Private Bucket", s3, public=False)

    print(f"\n{GREEN}{BOLD}{'═' * 52}")
    print(f"  ALL TESTS PASSED")
    print(f"{'═' * 52}{RESET}\n")

if __name__ == "__main__":
    main()
