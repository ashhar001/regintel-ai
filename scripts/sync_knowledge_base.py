#!/usr/bin/env python3
import argparse
import sys
import time

import boto3

TERMINAL = {"COMPLETE", "FAILED", "STOPPED"}


def main() -> None:
    parser = argparse.ArgumentParser(description="Start and wait for a Bedrock Knowledge Base sync.")
    parser.add_argument("--knowledge-base-id", required=True)
    parser.add_argument("--data-source-id", required=True)
    parser.add_argument("--profile", default=None)
    parser.add_argument("--region", default="us-east-1")
    args = parser.parse_args()

    session = boto3.Session(profile_name=args.profile, region_name=args.region)
    client = session.client("bedrock-agent")

    response = client.start_ingestion_job(
        knowledgeBaseId=args.knowledge_base_id,
        dataSourceId=args.data_source_id,
        description="RegIntel Stage 2 ingestion",
    )
    job = response["ingestionJob"]
    job_id = job["ingestionJobId"]
    print(f"started ingestion job {job_id}")

    while True:
        response = client.get_ingestion_job(
            knowledgeBaseId=args.knowledge_base_id,
            dataSourceId=args.data_source_id,
            ingestionJobId=job_id,
        )
        job = response["ingestionJob"]
        status = job["status"]
        stats = job.get("statistics", {})
        print(f"status={status} statistics={stats}")
        if status in TERMINAL:
            if status != "COMPLETE":
                print(f"failure_reasons={job.get('failureReasons', [])}", file=sys.stderr)
                raise SystemExit(1)
            return
        time.sleep(10)


if __name__ == "__main__":
    main()
