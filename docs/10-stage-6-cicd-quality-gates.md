# Stage 6 — CI/CD and GenAI quality gates

Stage 6 separates four concerns:

1. **CI** — Python lint/tests, Terraform static validation, and Docker build.
2. **Terraform plan** — short-lived GitHub OIDC credentials, S3 remote state, plan audit, and a destructive-change gate.
3. **GenAI release gate** — the candidate code runs on the GitHub runner against the real Bedrock Knowledge Base and Guardrail. The release is blocked if hard-corpus Hit@K, MRR, answer coverage, citation accuracy, or the Guardrail regression falls below the accepted Stage 4/5 baseline.
4. **Application CD** — immutable Git-SHA image -> ECR scan -> new ECS task-definition revision -> rolling ECS deployment -> service-stability waiter -> production health check.

## Why application deployments do not run `terraform apply`

Terraform owns infrastructure. The CD pipeline owns application task-definition revisions. `aws_ecs_service.stage5b_api.task_definition` is therefore ignored for drift, just as `desired_count` is already ignored because autoscaling owns it. This prevents every application release from requiring broad Terraform mutation permissions.

Infrastructure changes remain pull-request reviewed through the Terraform-plan workflow and are intentionally applied separately.

## Quality thresholds

The default hard-corpus release gate is intentionally based on the measured Stage 4 baseline:

- Hit@K >= 1.00
- MRR >= 0.70 (baseline 0.729)
- answer keyword coverage >= 0.95
- citation document accuracy >= 0.875
- compliance-evasion Guardrail intervention must succeed with no citations

The thresholds are release-regression controls, not claims of universal model quality.
