import hashlib
import json
import os
import re
from datetime import date, datetime, timezone
from pathlib import PurePosixPath
from urllib.parse import unquote_plus

import boto3
from botocore.exceptions import ClientError

s3 = boto3.client("s3")
dynamodb = boto3.client("dynamodb")

TABLE_NAME = os.environ["INGESTION_TABLE_NAME"]
MAX_DOCUMENT_BYTES = int(os.environ.get("MAX_DOCUMENT_BYTES", str(50 * 1024 * 1024)))
SUPPORTED_EXTENSIONS = {
    item.strip().lower()
    for item in os.environ.get(
        "SUPPORTED_EXTENSIONS", ".txt,.md,.html,.doc,.docx,.csv,.xls,.xlsx,.pdf"
    ).split(",")
    if item.strip()
}

REQUIRED_MANIFEST_FIELDS = {
    "document_id",
    "regulator",
    "jurisdiction",
    "document_type",
    "topic",
    "entity_type",
    "publication_date",
    "source_key",
}


def _safe_segment(value: str) -> str:
    normalized = re.sub(r"[^a-zA-Z0-9._-]+", "-", value.strip())
    normalized = normalized.strip("-._")
    if not normalized:
        raise ValueError("metadata value produced an empty path segment")
    return normalized[:120]


def _extract_event(event: object) -> dict:
    # EventBridge Pipes -> Step Functions delivers a JSON array even with batch size 1.
    if isinstance(event, list):
        if len(event) != 1:
            raise ValueError(f"expected exactly one pipe record, got {len(event)}")
        event = event[0]
    if not isinstance(event, dict):
        raise ValueError("workflow input must be a JSON object")
    if isinstance(event.get("event"), dict):
        return event["event"]
    return event


def _manifest_location(event: dict) -> tuple[str, str]:
    detail = event.get("detail", {})
    bucket = detail.get("bucket", {}).get("name")
    key = detail.get("object", {}).get("key")
    if not bucket or not key:
        raise ValueError("S3 EventBridge event is missing detail.bucket.name or detail.object.key")
    return bucket, unquote_plus(key)


def _load_json(bucket: str, key: str) -> dict:
    response = s3.get_object(Bucket=bucket, Key=key)
    body = response["Body"].read()
    try:
        result = json.loads(body)
    except json.JSONDecodeError as exc:
        raise ValueError(f"manifest {key} is not valid JSON") from exc
    if not isinstance(result, dict):
        raise ValueError("manifest root must be an object")
    return result


def _validate_manifest(manifest: dict) -> None:
    missing = sorted(REQUIRED_MANIFEST_FIELDS - manifest.keys())
    if missing:
        raise ValueError(f"manifest missing required fields: {', '.join(missing)}")

    source_key = str(manifest["source_key"])
    if not source_key.startswith("incoming/documents/"):
        raise ValueError("source_key must start with incoming/documents/")

    suffix = PurePosixPath(source_key).suffix.lower()
    if suffix not in SUPPORTED_EXTENSIONS:
        raise ValueError(f"unsupported source extension {suffix!r}")

    date.fromisoformat(str(manifest["publication_date"]))
    if manifest.get("effective_date"):
        date.fromisoformat(str(manifest["effective_date"]))

    for field in (
        "document_id",
        "regulator",
        "jurisdiction",
        "document_type",
        "topic",
        "entity_type",
    ):
        if not str(manifest[field]).strip():
            raise ValueError(f"manifest field {field} cannot be empty")


def _sha256_object(bucket: str, key: str) -> tuple[str, dict]:
    head = s3.head_object(Bucket=bucket, Key=key)
    size = int(head["ContentLength"])
    if size <= 0:
        raise ValueError("source document is empty")
    if size > MAX_DOCUMENT_BYTES:
        raise ValueError(
            f"source document is {size} bytes; max allowed is {MAX_DOCUMENT_BYTES} bytes"
        )

    digest = hashlib.sha256()
    response = s3.get_object(Bucket=bucket, Key=key)
    stream = response["Body"]
    while True:
        chunk = stream.read(1024 * 1024)
        if not chunk:
            break
        digest.update(chunk)

    return digest.hexdigest(), {
        "size_bytes": size,
        "etag": str(head.get("ETag", "")).strip('"'),
        "version_id": head.get("VersionId"),
    }


def _put_idempotency_record(item: dict) -> tuple[bool, dict | None]:
    try:
        dynamodb.put_item(
            TableName=TABLE_NAME,
            Item={
                "ingestion_fingerprint": {"S": item["ingestion_fingerprint"]},
                "content_sha256": {"S": item["content_sha256"]},
                "document_id": {"S": item["document_id"]},
                "status": {"S": "PROCESSING"},
                "source_bucket": {"S": item["bucket"]},
                "source_key": {"S": item["source_key"]},
                "manifest_key": {"S": item["manifest_key"]},
                "created_at": {"S": item["created_at"]},
                "updated_at": {"S": item["created_at"]},
            },
            ConditionExpression="attribute_not_exists(ingestion_fingerprint)",
        )
        return False, None
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") != "ConditionalCheckFailedException":
            raise
        existing = dynamodb.get_item(
            TableName=TABLE_NAME,
            Key={"ingestion_fingerprint": {"S": item["ingestion_fingerprint"]}},
            ConsistentRead=True,
        ).get("Item")
        existing_status = (existing or {}).get("status", {}).get("S")
        if existing_status == "FAILED":
            now = item["created_at"]
            dynamodb.update_item(
                TableName=TABLE_NAME,
                Key={"ingestion_fingerprint": {"S": item["ingestion_fingerprint"]}},
                UpdateExpression=(
                    "SET #status = :processing, source_key = :source_key, "
                    "manifest_key = :manifest_key, updated_at = :updated_at"
                ),
                ConditionExpression="#status = :failed",
                ExpressionAttributeNames={"#status": "status"},
                ExpressionAttributeValues={
                    ":processing": {"S": "PROCESSING"},
                    ":failed": {"S": "FAILED"},
                    ":source_key": {"S": item["source_key"]},
                    ":manifest_key": {"S": item["manifest_key"]},
                    ":updated_at": {"S": now},
                },
            )
            return False, existing
        return True, existing


def lambda_handler(event, _context):
    s3_event = _extract_event(event)
    bucket, manifest_key = _manifest_location(s3_event)

    if not manifest_key.startswith("incoming/manifests/") or not manifest_key.endswith(
        ".manifest.json"
    ):
        raise ValueError("only incoming/manifests/*.manifest.json can trigger ingestion")

    manifest = _load_json(bucket, manifest_key)
    _validate_manifest(manifest)

    source_key = str(manifest["source_key"])
    content_sha256, source = _sha256_object(bucket, source_key)

    source_name = _safe_segment(PurePosixPath(source_key).name)
    regulator_segment = _safe_segment(str(manifest["regulator"]).lower())
    document_segment = _safe_segment(str(manifest["document_id"]))
    destination_key = (
        f"documents/{regulator_segment}/{document_segment}/"
        f"{content_sha256[:12]}/{source_name}"
    )

    publication = date.fromisoformat(str(manifest["publication_date"]))
    publication_epoch = int(
        datetime(
            publication.year,
            publication.month,
            publication.day,
            tzinfo=timezone.utc,
        ).timestamp()
    )

    canonical_metadata = {
        "document_id": str(manifest["document_id"]),
        "regulator": str(manifest["regulator"]),
        "jurisdiction": str(manifest["jurisdiction"]),
        "document_type": str(manifest["document_type"]),
        "topic": str(manifest["topic"]),
        "entity_type": str(manifest["entity_type"]),
        "publication_date": str(manifest["publication_date"]),
        "effective_date": str(manifest.get("effective_date") or manifest["publication_date"]),
    }
    metadata_fingerprint_input = json.dumps(
        canonical_metadata, sort_keys=True, separators=(",", ":")
    )
    ingestion_fingerprint = hashlib.sha256(
        f"{content_sha256}:{metadata_fingerprint_input}".encode("utf-8")
    ).hexdigest()
    ingestion_token = hashlib.sha256(
        f"{ingestion_fingerprint}:{manifest_key}".encode("utf-8")
    ).hexdigest()

    now = datetime.now(timezone.utc).isoformat()
    prepared = {
        "bucket": bucket,
        "manifest_key": manifest_key,
        "source_key": source_key,
        "destination_key": destination_key,
        "metadata_key": f"{destination_key}.metadata.json",
        "content_sha256": content_sha256,
        "ingestion_fingerprint": ingestion_fingerprint,
        "ingestion_token": ingestion_token,
        "document_id": str(manifest["document_id"]),
        "regulator": str(manifest["regulator"]),
        "jurisdiction": str(manifest["jurisdiction"]),
        "document_type": str(manifest["document_type"]),
        "topic": str(manifest["topic"]),
        "entity_type": str(manifest["entity_type"]),
        "publication_date": str(manifest["publication_date"]),
        "publication_epoch": publication_epoch,
        "effective_date": str(manifest.get("effective_date") or manifest["publication_date"]),
        "title": str(manifest.get("title") or source_name),
        "size_bytes": source["size_bytes"],
        "etag": source["etag"],
        "source_version_id": source["version_id"],
        "created_at": now,
        "event_id": str(s3_event.get("id", "")),
    }

    duplicate, existing = _put_idempotency_record(prepared)
    prepared["duplicate"] = duplicate
    if existing:
        prepared["existing_status"] = existing.get("status", {}).get("S")

    return prepared
