#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <email> [password]" >&2
  exit 1
fi

EMAIL="$1"
PASSWORD="${2:-}"
PROFILE="${AWS_PROFILE:-tenderly}"
REGION="${AWS_REGION:-us-east-1}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/infrastructure/terraform/stage2"

if [[ -z "${PASSWORD}" ]]; then
  read -r -s -p "Permanent password: " PASSWORD
  echo
fi

USER_POOL_ID="$(terraform -chdir="${TF_DIR}" output -raw stage5b_cognito_user_pool_id)"
CLIENT_ID="$(terraform -chdir="${TF_DIR}" output -raw stage5b_cognito_app_client_id)"

if ! aws cognito-idp admin-get-user \
  --user-pool-id "${USER_POOL_ID}" \
  --username "${EMAIL}" \
  --profile "${PROFILE}" \
  --region "${REGION}" >/dev/null 2>&1; then
  aws cognito-idp admin-create-user \
    --user-pool-id "${USER_POOL_ID}" \
    --username "${EMAIL}" \
    --user-attributes Name=email,Value="${EMAIL}" Name=email_verified,Value=true \
    --temporary-password "${PASSWORD}" \
    --message-action SUPPRESS \
    --profile "${PROFILE}" \
    --region "${REGION}" >/dev/null
fi

aws cognito-idp admin-set-user-password \
  --user-pool-id "${USER_POOL_ID}" \
  --username "${EMAIL}" \
  --password "${PASSWORD}" \
  --permanent \
  --profile "${PROFILE}" \
  --region "${REGION}"

TOKEN="$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id "${CLIENT_ID}" \
  --auth-parameters USERNAME="${EMAIL}",PASSWORD="${PASSWORD}" \
  --profile "${PROFILE}" \
  --region "${REGION}" \
  --query 'AuthenticationResult.IdToken' \
  --output text)"

cat <<MSG
User is ready.

Export this token in the current shell if you want to test immediately:

export REGINTEL_TOKEN='${TOKEN}'
MSG
