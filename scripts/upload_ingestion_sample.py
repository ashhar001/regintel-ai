#!/usr/bin/env python3
import argparse
import json
import uuid
from pathlib import Path

import boto3


def parse_args():
    parser = argparse.ArgumentParser(
        description="Upload a Stage 3 document and trigger manifest"
    )
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--profile", default=None)
    parser.add_argument("--region", default="us-east-1")
    return parser.parse_args()


def main():
    args = parse_args()
    session = boto3.Session(profile_name=args.profile, region_name=args.region)
    s3 = session.client("s3")

    root = Path(__file__).resolve().parents[1]
    source = root / "sample-data" / "regintel-test" / "regintel-policy-002.txt"
    source_key = "incoming/documents/regintel-policy-002.txt"
    manifest_key = (
        f"incoming/manifests/regintel-policy-002-{uuid.uuid4().hex}.manifest.json"
    )

    manifest = {
        "document_id": "REGINTEL-TEST-002",
        "title": "RegIntel Test Regulatory Policy 002",
        "regulator": "REGINTEL_TEST",
        "jurisdiction": "TEST",
        "document_type": "policy",
        "topic": "AML",
        "entity_type": "regulated_institution",
        "publication_date": "2026-09-16",
        "effective_date": "2026-10-01",
        "source_key": source_key,
    }

    # Upload the payload first. The manifest is the transaction/trigger boundary.
    s3.upload_file(str(source), args.bucket, source_key)
    s3.put_object(
        Bucket=args.bucket,
        Key=manifest_key,
        Body=json.dumps(manifest).encode("utf-8"),
        ContentType="application/json",
    )

    print(f"uploaded document s3://{args.bucket}/{source_key}")
    print(f"uploaded trigger manifest s3://{args.bucket}/{manifest_key}")


if __name__ == "__main__":
    main()
