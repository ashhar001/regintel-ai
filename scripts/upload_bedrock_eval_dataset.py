#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

import boto3


def main() -> None:
    parser = argparse.ArgumentParser(description="Upload Bedrock RAG evaluation dataset to S3.")
    parser.add_argument("--file", default="evaluation/datasets/bedrock-rag-eval.jsonl")
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--key", default="stage4/input/bedrock-rag-eval.jsonl")
    parser.add_argument("--profile", default=None)
    parser.add_argument("--region", default="us-east-1")
    args = parser.parse_args()

    path = Path(args.file)
    if not path.is_file():
        raise SystemExit(f"dataset not found: {path}")

    session = boto3.Session(profile_name=args.profile, region_name=args.region)
    s3 = session.client("s3")
    s3.upload_file(str(path), args.bucket, args.key)
    print(f"s3://{args.bucket}/{args.key}")


if __name__ == "__main__":
    main()
