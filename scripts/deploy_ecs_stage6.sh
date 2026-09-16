#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${ECS_CLUSTER:?ECS_CLUSTER is required}"
: "${ECS_SERVICE:?ECS_SERVICE is required}"
: "${IMAGE_URI:?IMAGE_URI is required}"

CONTAINER_NAME="${CONTAINER_NAME:-regintel-api}"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

CURRENT_TASK_DEFINITION=$(aws ecs describe-services \
  --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --query 'services[0].taskDefinition' \
  --output text)

echo "Current task definition: $CURRENT_TASK_DEFINITION"

aws ecs describe-task-definition \
  --region "$AWS_REGION" \
  --task-definition "$CURRENT_TASK_DEFINITION" \
  --query 'taskDefinition' \
  --output json > "$TMP_DIR/current.json"

jq --arg image "$IMAGE_URI" --arg name "$CONTAINER_NAME" '
  .containerDefinitions |= map(if .name == $name then .image = $image else . end)
  | del(
      .taskDefinitionArn,
      .revision,
      .status,
      .requiresAttributes,
      .compatibilities,
      .registeredAt,
      .registeredBy
    )
' "$TMP_DIR/current.json" > "$TMP_DIR/next.json"

NEW_TASK_DEFINITION=$(aws ecs register-task-definition \
  --region "$AWS_REGION" \
  --cli-input-json "file://$TMP_DIR/next.json" \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "Registered: $NEW_TASK_DEFINITION"

aws ecs update-service \
  --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --task-definition "$NEW_TASK_DEFINITION" \
  --force-new-deployment \
  >/dev/null

set +e
aws ecs wait services-stable \
  --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE"
WAIT_STATUS=$?
set -e

if (( WAIT_STATUS != 0 )); then
  echo "ECS did not stabilize. Recent service events:"
  aws ecs describe-services \
    --region "$AWS_REGION" \
    --cluster "$ECS_CLUSTER" \
    --services "$ECS_SERVICE" \
    --query 'services[0].events[:10].[createdAt,message]' \
    --output table || true
  exit "$WAIT_STATUS"
fi

RUNNING=$(aws ecs describe-services \
  --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --query 'services[0].runningCount' \
  --output text)
DESIRED=$(aws ecs describe-services \
  --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --query 'services[0].desiredCount' \
  --output text)

echo "ECS stable: running=$RUNNING desired=$DESIRED task_definition=$NEW_TASK_DEFINITION"
