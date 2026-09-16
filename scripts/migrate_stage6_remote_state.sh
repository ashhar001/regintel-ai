#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BOOTSTRAP_DIR="$ROOT/infrastructure/terraform/bootstrap-stage6"
MAIN_DIR="$ROOT/infrastructure/terraform/stage2"
AWS_PROFILE_NAME="${AWS_PROFILE:-tenderly}"
AWS_REGION_NAME="${AWS_REGION:-us-east-1}"

STATE_BUCKET=$(terraform -chdir="$BOOTSTRAP_DIR" output -raw terraform_state_bucket)
STATE_KEY=$(terraform -chdir="$BOOTSTRAP_DIR" output -raw terraform_state_key)
BACKEND_FILE="$MAIN_DIR/.stage6.backend.hcl"

cat > "$BACKEND_FILE" <<EOF2
bucket       = "$STATE_BUCKET"
key          = "$STATE_KEY"
region       = "$AWS_REGION_NAME"
use_lockfile = true
EOF2

mkdir -p "$MAIN_DIR/state-backups"
if [[ -f "$MAIN_DIR/terraform.tfstate" ]]; then
  STAMP=$(date -u +%Y%m%dT%H%M%SZ)
  cp "$MAIN_DIR/terraform.tfstate" "$MAIN_DIR/state-backups/terraform.tfstate.$STAMP"
  echo "Backed up local state to state-backups/terraform.tfstate.$STAMP"
fi

export AWS_PROFILE="$AWS_PROFILE_NAME"
export AWS_REGION="$AWS_REGION_NAME"

terraform -chdir="$MAIN_DIR" init \
  -migrate-state \
  -force-copy \
  -backend-config="$BACKEND_FILE"

terraform -chdir="$MAIN_DIR" state pull >/dev/null

echo "Remote-state migration verified."
echo "Bucket: $STATE_BUCKET"
echo "Key:    $STATE_KEY"
