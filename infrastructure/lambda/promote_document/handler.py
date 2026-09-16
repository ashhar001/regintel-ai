import json
import os
from datetime import datetime, timezone

import boto3

s3 = boto3.client("s3")
dynamodb = boto3.client("dynamodb")
TABLE_NAME = os.environ["INGESTION_TABLE_NAME"]


def lambda_handler(event, _context):
    bucket = event["bucket"]
    source_key = event["source_key"]
    destination_key = event["destination_key"]
    metadata_key = event["metadata_key"]
    fingerprint = event["ingestion_fingerprint"]

    copy_source = {"Bucket": bucket, "Key": source_key}
    if event.get("source_version_id"):
        copy_source["VersionId"] = event["source_version_id"]

    s3.copy_object(
        Bucket=bucket,
        Key=destination_key,
        CopySource=copy_source,
        MetadataDirective="COPY",
    )

    metadata_attributes = {
        "document_id": event["document_id"],
        "regulator": event["regulator"],
        "jurisdiction": event["jurisdiction"],
        "document_type": event["document_type"],
        "topic": event["topic"],
        "entity_type": event["entity_type"],
        "publication_date": event["publication_date"],
        "publication_epoch": event["publication_epoch"],
        "effective_date": event["effective_date"],
    }
    sidecar = json.dumps(
        {"metadataAttributes": metadata_attributes},
        separators=(",", ":"),
    ).encode("utf-8")

    s3.put_object(
        Bucket=bucket,
        Key=metadata_key,
        Body=sidecar,
        ContentType="application/json",
    )

    now = datetime.now(timezone.utc).isoformat()
    dynamodb.update_item(
        TableName=TABLE_NAME,
        Key={"ingestion_fingerprint": {"S": fingerprint}},
        UpdateExpression=(
            "SET #status = :status, destination_key = :destination_key, "
            "metadata_key = :metadata_key, updated_at = :updated_at"
        ),
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={
            ":status": {"S": "PROMOTED"},
            ":destination_key": {"S": destination_key},
            ":metadata_key": {"S": metadata_key},
            ":updated_at": {"S": now},
        },
    )

    return event
