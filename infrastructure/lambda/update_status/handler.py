import json
import os
from datetime import datetime, timezone

import boto3

dynamodb = boto3.client("dynamodb")
TABLE_NAME = os.environ["INGESTION_TABLE_NAME"]


def _string(value) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    return json.dumps(value, default=str, separators=(",", ":"))


def lambda_handler(event, _context):
    fingerprint = event["ingestion_fingerprint"]
    status = event["status"]
    now = datetime.now(timezone.utc).isoformat()

    names = {"#status": "status"}
    values = {
        ":status": {"S": status},
        ":updated_at": {"S": now},
    }
    expressions = ["#status = :status", "updated_at = :updated_at"]

    if event.get("ingestion_job_id"):
        values[":job"] = {"S": _string(event["ingestion_job_id"])}
        expressions.append("ingestion_job_id = :job")

    if event.get("details") is not None:
        values[":details"] = {"S": _string(event["details"])[:3500]}
        expressions.append("details = :details")

    dynamodb.update_item(
        TableName=TABLE_NAME,
        Key={"ingestion_fingerprint": {"S": fingerprint}},
        UpdateExpression="SET " + ", ".join(expressions),
        ExpressionAttributeNames=names,
        ExpressionAttributeValues=values,
    )

    return event
