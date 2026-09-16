# RegIntel Stage 6 overlay

Adds production CI/CD and GenAI release gates without changing the RAG algorithm.

## Included

- GitHub Actions CI
- GitHub OIDC — no long-lived AWS access keys
- versioned S3 Terraform remote state with native S3 lockfile
- PR Terraform plan + destructive-change gate
- hard-corpus RAG release gate
- Guardrail regression gate
- immutable Git-SHA ECR images
- ECR vulnerability gate
- ECS rolling deployment with service-stability verification
- post-deployment health check
- Dependabot for Actions/Python dependencies

Follow the runbook in the accompanying ChatGPT instructions. The one-time order is:

1. Apply `bootstrap-stage6` locally.
2. Migrate the existing `stage2` Terraform state to the S3 backend.
3. Apply the additive Stage 6 AOSS CI access policy locally.
4. Configure GitHub repository variables.
5. Add protection to the GitHub `production` Environment.
6. Push a branch / open a PR and observe the gates.
