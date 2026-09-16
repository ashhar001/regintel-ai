#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BOOTSTRAP_DIR="$ROOT/infrastructure/terraform/bootstrap-stage6"
MAIN_DIR="$ROOT/infrastructure/terraform/stage2"
PROFILE="${AWS_PROFILE:-tenderly}"
REGION="${AWS_REGION:-us-east-1}"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required for this helper. Install/login to gh or set the variables manually."
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Run: gh auth login"
  exit 1
fi

PLAN_ROLE=$(terraform -chdir="$BOOTSTRAP_DIR" output -raw github_terraform_plan_role_arn)
DEPLOY_ROLE=$(terraform -chdir="$BOOTSTRAP_DIR" output -raw github_deploy_role_arn)
STATE_BUCKET=$(terraform -chdir="$BOOTSTRAP_DIR" output -raw terraform_state_bucket)
STATE_KEY=$(terraform -chdir="$BOOTSTRAP_DIR" output -raw terraform_state_key)

ECR_URL=$(terraform -chdir="$MAIN_DIR" output -raw stage5b_ecr_repository_url)
ECR_NAME="${ECR_URL##*/}"
ECS_CLUSTER=$(terraform -chdir="$MAIN_DIR" output -raw stage5b_ecs_cluster_name)
ECS_SERVICE=$(terraform -chdir="$MAIN_DIR" output -raw stage5b_ecs_service_name)
API_URL=$(terraform -chdir="$MAIN_DIR" output -raw stage5b_api_base_url)
KB_ID=$(terraform -chdir="$MAIN_DIR" output -raw knowledge_base_id)
RAG_MODEL=$(terraform -chdir="$MAIN_DIR" output -raw rag_model_arn)
GUARDRAIL_ID=$(terraform -chdir="$MAIN_DIR" output -raw guardrail_id)
GUARDRAIL_VERSION=$(terraform -chdir="$MAIN_DIR" output -raw guardrail_version)
RERANK_MODEL=$(terraform -chdir="$MAIN_DIR" output -raw rerank_model_arn)

CALLER_ARN=$(aws sts get-caller-identity --profile "$PROFILE" --region "$REGION" --query Arn --output text)
if [[ "$CALLER_ARN" == arn:aws:sts::*:assumed-role/* ]]; then
  ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --region "$REGION" --query Account --output text)
  ROLE_NAME=$(sed -E 's#arn:aws:sts::[0-9]+:assumed-role/([^/]+)/.*#\1#' <<<"$CALLER_ARN")
  AOSS_ADMIN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
else
  AOSS_ADMIN="$CALLER_ARN"
fi

set_var() {
  local key="$1" value="$2"
  echo "Setting $key"
  gh variable set "$key" --body "$value"
}

set_var AWS_REGION "$REGION"
set_var AWS_TERRAFORM_PLAN_ROLE_ARN "$PLAN_ROLE"
set_var AWS_DEPLOY_ROLE_ARN "$DEPLOY_ROLE"
set_var TF_STATE_BUCKET "$STATE_BUCKET"
set_var TF_STATE_KEY "$STATE_KEY"
set_var AOSS_ADMIN_PRINCIPAL_ARN "$AOSS_ADMIN"
set_var ECR_REPOSITORY_URL "$ECR_URL"
set_var ECR_REPOSITORY_NAME "$ECR_NAME"
set_var ECS_CLUSTER "$ECS_CLUSTER"
set_var ECS_SERVICE "$ECS_SERVICE"
set_var API_BASE_URL "$API_URL"
set_var BEDROCK_KNOWLEDGE_BASE_ID "$KB_ID"
set_var BEDROCK_RAG_MODEL_ARN "$RAG_MODEL"
set_var BEDROCK_GUARDRAIL_ID "$GUARDRAIL_ID"
set_var BEDROCK_GUARDRAIL_VERSION "$GUARDRAIL_VERSION"
set_var BEDROCK_RERANK_MODEL_ARN "$RERANK_MODEL"

echo "GitHub repository variables configured."
