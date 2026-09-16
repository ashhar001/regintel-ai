#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/infrastructure/terraform/stage2"
PROFILE="${AWS_PROFILE:-tenderly}"
REGION="${AWS_REGION:-us-east-1}"
IMAGE_TAG="${1:-stage5b}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required" >&2
  exit 1
fi

REPOSITORY_URL="$(terraform -chdir="${TF_DIR}" output -raw stage5b_ecr_repository_url)"
REGISTRY="${REPOSITORY_URL%%/*}"

aws ecr get-login-password \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  | docker login --username AWS --password-stdin "${REGISTRY}"

echo "Building ${REPOSITORY_URL}:${IMAGE_TAG} for linux/amd64"
docker build \
  --platform linux/amd64 \
  -f "${ROOT_DIR}/backend/Dockerfile" \
  -t "${REPOSITORY_URL}:${IMAGE_TAG}" \
  "${ROOT_DIR}"

docker push "${REPOSITORY_URL}:${IMAGE_TAG}"

cat <<MSG

Pushed: ${REPOSITORY_URL}:${IMAGE_TAG}

Now set these values in infrastructure/terraform/stage2/terraform.tfvars:

stage5b_image_tag       = "${IMAGE_TAG}"
stage5b_runtime_enabled = true

Then run terraform plan/apply again.
MSG
