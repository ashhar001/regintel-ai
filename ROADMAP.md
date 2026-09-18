# Roadmap

RegIntel AI v1 is a validated production RAG platform. The next work should make the project easier to reuse as a baseline while preserving the same quality, security, and observability contract.

## Near Term

- Improve onboarding for people adapting the architecture to their own AWS account.
- Add clearer diagrams for runtime, ingestion, CI/CD, and observability paths.
- Add more small, focused examples for safe Terraform changes.
- Expand tests around guardrails, reranking, release gates, and plan safety.
- Keep CI security scanning strict and documented.

## Reference Architecture Hardening

- Add optional modules or examples for alternate environments.
- Document bootstrap versus steady-state Terraform workflows more clearly.
- Keep IAM and network policies least-privilege and scanner-clean.
- Add cost and quota notes for Bedrock, OpenSearch Serverless, API Gateway, ECS, and CloudWatch.

## Product Expansion

- Authenticated analyst UI
- Streaming responses
- Citation/source viewer
- Feedback capture
- Query history
- Larger-corpus retrieval benchmarks
- Load, quota, throttling, and recovery exercises

## Contribution Areas

- Documentation and diagrams
- Evaluation datasets and scoring improvements
- Terraform security hardening
- CI/CD and release-gate improvements
- Observability dashboards, alarms, and incident runbooks
- Backend API tests and service behavior tests

See [`docs/02-roadmap.md`](docs/02-roadmap.md) for the full delivery history and expansion notes.
