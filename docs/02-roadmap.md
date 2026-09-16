# Delivery Roadmap

## Stage 0 — Production contract ✅
Product requirements, NFRs, architecture decisions, release gates.

## Stage 1 — Bedrock service foundation ✅
FastAPI service, Bedrock Converse API, Docker, configuration, logging, tests.

## Stage 2 — Core AWS RAG infrastructure 🚧
Terraform for KMS, S3, IAM, OpenSearch Serverless, Bedrock Knowledge Base and S3 data source; retrieval-only and retrieve-and-generate API paths; metadata filtering; first ingestion/smoke test.

Stage 2 becomes ✅ only after the deployed AWS smoke test in `docs/04-stage-2-runbook.md` passes.

## Stage 3 — Production ingestion pipeline
EventBridge, SQS, DLQ, Step Functions, Lambda validation, metadata enrichment, idempotency and KB sync.

## Stage 4 — Retrieval engineering
Metadata filters, semantic vs hybrid search, reranking, query rewriting/decomposition and citation contract.

## Stage 5 — Security and identity
Cognito, API Gateway, WAF, Guardrails, IAM boundaries, secrets, private networking decisions and audit controls.

## Stage 6 — Evaluation
Gold dataset, retrieve-only evaluation, retrieve-and-generate evaluation, custom metrics and regression thresholds.

## Stage 7 — Observability and SRE
CloudWatch dashboards, traces, token/cost metrics, alarms, SLOs, failure injection and runbooks.

## Stage 8 — CI/CD and environments
GitHub Actions, Terraform plan/apply workflow, dev/stage/prod promotion, evaluation gates and rollback.

## Stage 9 — UI
Production-quality analyst UI with authentication, streaming answers, source viewer and feedback capture.

## Stage 10 — Agentic workflow
Document comparison/action-plan workflow with tool use and explicit human approval.

## Stage 11 — Production hardening
Load tests, quota tests, disaster recovery, cost review, security review and threat model.

## Stage 12 — Portfolio release
Architecture diagram, benchmark report, demo video, polished GitHub README and LinkedIn case study.
