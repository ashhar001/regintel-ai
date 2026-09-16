# Stage 5B — Private Fargate Runtime + Cognito + WAF

Stage 5B moves RegIntel from local Uvicorn to an authenticated AWS-hosted runtime without changing the RAG implementation.

## Request path

```text
Internet
  |
AWS WAF
  |
API Gateway REST API (Regional)
  |  Cognito authorizer for /v1/*
  |
API Gateway VPC Link
  |
Internal Network Load Balancer
  |
ECS Fargate tasks (private subnets, no public IP)
  |
PrivateLink
  +-- bedrock-runtime
  +-- bedrock-agent-runtime
```

ECR API/DKR and CloudWatch Logs also use interface endpoints. S3 uses a gateway endpoint for ECR image layer downloads. There is no NAT gateway in this stage.

## Why NLB here?

API Gateway REST APIs have a stable VPC Link integration path to an NLB, while REST API stages support direct AWS WAF association and Cognito user-pool authorizers. The application remains private; only API Gateway is publicly reachable.

## Two-phase deployment

### Phase A — bootstrap

Keep:

```hcl
stage5b_runtime_enabled = false
```

Apply Terraform. This creates ECR, VPC, endpoints, ECS cluster/task definition, NLB, Cognito, API Gateway, and WAF but does not start a service before an image exists.

### Phase B — image + service

Build and push:

```bash
./scripts/build_push_stage5b.sh stage5b-v1
```

Then set:

```hcl
stage5b_image_tag       = "stage5b-v1"
stage5b_runtime_enabled = true
```

Plan/apply again. Terraform creates the ECS service and autoscaling policy.

## Security characteristics

- ECS tasks have no public IP.
- There is no internet gateway or NAT gateway in the application VPC.
- Bedrock calls stay on PrivateLink because private DNS is enabled for the endpoints.
- `/health` is intentionally unauthenticated for operational checks.
- `/v1/*` requires a valid Cognito token.
- WAF evaluates requests before the Cognito authorizer.
- ECS task role is least-privilege for the current Bedrock KB/model/reranker/guardrail workflow.
- ECR tags are immutable and images are scanned on push.

## Known hardening item

The original Stage 2 OpenSearch Serverless network policy remains publicly reachable but IAM/data-policy protected because Terraform is still executed from a developer laptop and directly manages the OpenSearch index. The RegIntel application never connects directly to OpenSearch; Bedrock Knowledge Bases does. A later hardening step can move Terraform execution into a private CI runner/VPC and then remove public AOSS access.
