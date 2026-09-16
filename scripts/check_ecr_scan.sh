#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${ECR_REPOSITORY_NAME:?ECR_REPOSITORY_NAME is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"

MAX_CRITICAL="${MAX_CRITICAL:-0}"
MAX_HIGH="${MAX_HIGH:-999999}"

for attempt in $(seq 1 30); do
  STATUS=$(aws ecr describe-image-scan-findings \
    --region "$AWS_REGION" \
    --repository-name "$ECR_REPOSITORY_NAME" \
    --image-id "imageTag=$IMAGE_TAG" \
    --query 'imageScanStatus.status' \
    --output text 2>/dev/null || true)

  if [[ "$STATUS" == "COMPLETE" || "$STATUS" == "ACTIVE" ]]; then
    break
  fi
  if [[ "$STATUS" == "FAILED" ]]; then
    echo "ECR image scan failed."
    exit 1
  fi
  sleep 4
done

FINDINGS=$(aws ecr describe-image-scan-findings \
  --region "$AWS_REGION" \
  --repository-name "$ECR_REPOSITORY_NAME" \
  --image-id "imageTag=$IMAGE_TAG" \
  --query 'imageScanFindings.findingSeverityCounts' \
  --output json)

CRITICAL=$(jq -r '.CRITICAL // 0' <<<"$FINDINGS")
HIGH=$(jq -r '.HIGH // 0' <<<"$FINDINGS")

echo "ECR scan: CRITICAL=$CRITICAL HIGH=$HIGH"

if (( CRITICAL > MAX_CRITICAL )); then
  echo "Release blocked: critical vulnerabilities exceed threshold $MAX_CRITICAL."
  exit 1
fi
if (( HIGH > MAX_HIGH )); then
  echo "Release blocked: high vulnerabilities exceed threshold $MAX_HIGH."
  exit 1
fi
