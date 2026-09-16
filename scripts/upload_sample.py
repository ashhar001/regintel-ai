#!/usr/bin/env python3
import argparse
from pathlib import Path

import boto3


def main() -> None:
    parser = argparse.ArgumentParser(description="Upload the Stage 2 synthetic RAG test document.")
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--profile", default=None)
    parser.add_argument("--region", default="us-east-1")
    args = parser.parse_args()

    session = boto3.Session(profile_name=args.profile, region_name=args.region)
    s3 = session.client("s3")
    source_dir = Path(__file__).resolve().parents[1] / "sample-data" / "regintel-test"

    for path in sorted(source_dir.iterdir()):
        if not path.is_file():
            continue
        key = f"documents/{path.name}"
        s3.upload_file(str(path), args.bucket, key)
        print(f"uploaded s3://{args.bucket}/{key}")


if __name__ == "__main__":
    main()
