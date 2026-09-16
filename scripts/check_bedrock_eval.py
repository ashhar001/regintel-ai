#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json

import boto3


def main() -> None:
    parser = argparse.ArgumentParser(description="Check an Amazon Bedrock evaluation job.")
    parser.add_argument("--job-arn", required=True)
    parser.add_argument("--profile", default=None)
    parser.add_argument("--region", default="us-east-1")
    args = parser.parse_args()

    session = boto3.Session(profile_name=args.profile, region_name=args.region)
    client = session.client("bedrock")
    response = client.get_evaluation_job(jobIdentifier=args.job_arn)
    wanted = {
        key: response.get(key)
        for key in [
            "jobName",
            "status",
            "failureMessages",
            "creationTime",
            "lastModifiedTime",
            "outputDataConfig",
        ]
        if key in response
    }
    print(json.dumps(wanted, indent=2, default=str))


if __name__ == "__main__":
    main()
