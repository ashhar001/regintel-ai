#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path

import boto3

DOCS = [
    ("aml-alert-legacy.txt", "REGINTEL-TEST-AML-LEGACY", "AML"),
    ("aml-alert-triage.txt", "REGINTEL-TEST-AML-TRIAGE", "AML"),
    ("aml-case-retention.txt", "REGINTEL-TEST-AML-RETENTION", "AML"),
    ("aml-escalation-sla.txt", "REGINTEL-TEST-AML-ESCALATION", "AML"),
    ("aml-batch-monitoring.txt", "REGINTEL-TEST-AML-BATCH", "AML"),
    ("kyc-review-legacy.txt", "REGINTEL-TEST-KYC-LEGACY", "KYC"),
    ("kyc-trigger-review.txt", "REGINTEL-TEST-KYC-TRIGGER", "KYC"),
    ("kyc-record-archive.txt", "REGINTEL-TEST-KYC-ARCHIVE", "KYC"),
]


def main() -> None:
    parser = argparse.ArgumentParser(description="Upload the Stage 4D hard retrieval corpus through the Stage 3 ingestion pipeline.")
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--profile", default=None)
    parser.add_argument("--region", default="us-east-1")
    parser.add_argument("--delay-seconds", type=float, default=2.0)
    args = parser.parse_args()

    session = boto3.Session(profile_name=args.profile, region_name=args.region)
    s3 = session.client("s3")
    root = Path(__file__).resolve().parents[1]
    corpus = root / "sample-data" / "regintel-hard"

    for filename, document_id, topic in DOCS:
        source = corpus / filename
        if not source.exists():
            raise FileNotFoundError(source)

        source_key = f"incoming/documents/{filename}"
        manifest_key = f"incoming/manifests/{Path(filename).stem}-{uuid.uuid4().hex[:10]}.manifest.json"
        current_date = datetime.now(timezone.utc).date().isoformat()
        manifest = {
            "document_id": document_id,
            "title": source.stem.replace("-", " ").title(),
            "regulator": "REGINTEL_TEST",
            "jurisdiction": "TEST",
            "document_type": "guidance",
            "topic": topic,
            "entity_type": "regulated_institution",
            "publication_date": current_date,
            "effective_date": current_date,
            "source_key": source_key,
        }

        s3.upload_file(str(source), args.bucket, source_key)
        s3.put_object(
            Bucket=args.bucket,
            Key=manifest_key,
            Body=(json.dumps(manifest, indent=2) + "\n").encode("utf-8"),
            ContentType="application/json",
        )
        print(f"queued {document_id}: s3://{args.bucket}/{manifest_key}")
        if args.delay_seconds:
            time.sleep(args.delay_seconds)


if __name__ == "__main__":
    main()
