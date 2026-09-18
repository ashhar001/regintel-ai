# Contributing to RegIntel AI

Thanks for helping improve RegIntel AI. This repository is intended to be a production-oriented reference architecture for secure, observable Amazon Bedrock RAG systems.

## Good First Contributions

- Documentation fixes or clearer setup steps
- New tests for existing behavior
- Terraform hardening that preserves least privilege
- Evaluation dataset improvements with clear expected answers
- Observability, SLO, and runbook improvements

## Before Opening a PR

1. Open or comment on an issue for non-trivial changes.
2. Keep changes focused and explain the production behavior being improved.
3. Do not commit secrets, `.env`, Terraform state, Terraform plans, account IDs, live API URLs, or local generated artifacts.
4. Preserve the infrastructure boundary: Terraform owns infrastructure; the deploy workflow owns promoted ECS task-definition revisions and immutable images.
5. Preserve release gates unless the PR explicitly improves them.

## Local Checks

Run the relevant checks before requesting review:

```bash
ruff check backend scripts
pytest -q backend/tests scripts/tests
terraform -chdir=infrastructure/terraform/stage2 fmt -check -recursive
terraform -chdir=infrastructure/terraform/stage2 validate -no-color
```

Security checks are also run in CI. If you touch dependencies, Terraform, Docker, CI, auth, IAM, networking, or release gates, expect the security scan and Terraform plan gate to be part of review.

## Pull Request Guidelines

- Describe what changed and why.
- Include test evidence.
- Call out any Terraform state moves, IAM scope changes, networking changes, or public API changes.
- Keep generated files out of the PR unless they are intentionally committed fixtures.

## Security

Please follow [`SECURITY.md`](SECURITY.md). Do not open public issues for suspected vulnerabilities or exposed credentials.
