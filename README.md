# RegIntel AI — Production Amazon Bedrock RAG Platform

RegIntel AI is a production-oriented financial/regulatory intelligence platform built on Amazon Bedrock. It demonstrates the full lifecycle of an enterprise RAG system: ingestion, retrieval, grounded generation, security, CI/CD, evaluation, observability, SLOs, tracing, and incident diagnostics.

This project is available under the Apache License 2.0 and is intended to be reusable as a baseline reference architecture. See [`CONTRIBUTING.md`](CONTRIBUTING.md), [`ROADMAP.md`](ROADMAP.md), and [`SECURITY.md`](SECURITY.md) before adapting or contributing changes.

## Status

**RegIntel AI v1 production platform: validated.**

Completed platform capabilities:

- FastAPI application runtime on ECS Fargate
- Amazon Bedrock Knowledge Bases
- Titan Text Embeddings V2
- OpenSearch Serverless vector search
- semantic and hybrid retrieval
- optional Cohere Rerank v3.5
- Amazon Nova Lite grounded generation
- citations and metadata filtering
- event-driven ingestion with EventBridge, SQS, Pipes, Step Functions and Lambda
- Bedrock Guardrails
- Cognito authentication
- AWS WAF
- API Gateway REST + VPC Link + internal NLB
- private ECS networking with no public IP
- GitHub Actions CI/CD with AWS OIDC
- immutable ECR commit-SHA image promotion
- RAG quality release gates
- CloudWatch EMF application metrics
- request correlation
- 99.9% availability SLO and error-budget burn alerts
- API Gateway X-Ray tracing
- incident-diagnostics dashboards and saved Logs Insights queries

See [`docs/12-v1-production-validation.md`](docs/12-v1-production-validation.md) for the final production validation record.

## Production architecture

```text
Client
  |
  v
AWS WAF
  |
  v
API Gateway REST API + Cognito + X-Ray
  |
  v
VPC Link
  |
  v
Internal Network Load Balancer
  |
  v
ECS Fargate / FastAPI
(private subnets, no public IP)
  |
  +--> Bedrock Knowledge Base / RetrieveAndGenerate
  |       |
  |       +--> OpenSearch Serverless vector index
  |       +--> Titan Text Embeddings V2
  |       +--> Cohere Rerank v3.5 when enabled
  |       +--> Amazon Nova Lite
  |
  +--> Bedrock Guardrails
```

### Ingestion

```text
S3 incoming
  -> EventBridge
  -> SQS
  -> EventBridge Pipes
  -> Step Functions
  -> validation / hashing / idempotency / promotion
  -> Bedrock Knowledge Base ingestion
  -> OpenSearch Serverless
```

### Observability

```text
API Gateway X-Ray
      |
      v
request_id + trace_id
      |
FastAPI structured logs + CloudWatch EMF
      |
      +--> SRE dashboard
      +--> SLO dashboard
      +--> incident diagnostics
      +--> alarms / burn-rate composites / SNS
```

## RAG endpoints

### Retrieval only

`POST /v1/rag/retrieve`

```json
{
  "query": "How long must verification records be retained?",
  "number_of_results": 5,
  "search_type": "HYBRID",
  "filters": {
    "regulator": "REGINTEL_TEST",
    "topic": "KYC"
  }
}
```

### Retrieve + generate

`POST /v1/rag/query`

```json
{
  "question": "How long must customer verification records be retained?",
  "number_of_results": 5,
  "search_type": "HYBRID",
  "filters": {
    "regulator": "REGINTEL_TEST",
    "topic": "KYC"
  }
}
```

The response contains a grounded answer, Bedrock session ID, latency and citations.

## Retrieval and quality contract

Frozen default retrieval mode:

- search type: `HYBRID`
- top K: `5`
- reranking: optional

Release thresholds:

| Metric | Required |
| --- | ---: |
| Hit@K | 1.00 |
| MRR | >= 0.70 |
| Answer coverage | >= 0.95 |
| Citation document accuracy | >= 0.875 |

Changes to retrieval, prompts, reranking or models must pass the versioned evaluation corpus before deployment.

## CI/CD

The production deployment pipeline performs:

1. lint and unit tests
2. live candidate API startup against real Bedrock services
3. hard-corpus RAG regression
4. guardrail regression
5. immutable container build
6. ECR critical-vulnerability gate
7. ECS task-definition revision deployment
8. ECS service stability check
9. public health check

Terraform PR plans are separately checked for destructive resource actions.

## SRE objectives

- availability SLO: **99.9% successful RAG queries**
- error budget: **0.1%**
- RAG latency objective: **p95 < 5 seconds**

Fast and slow multi-window burn-rate alarms route through CloudWatch composite alarms to the SRE SNS topic.

## Run locally

```bash
export AWS_PROFILE=tenderly
export AWS_REGION=us-east-1

python3 -m venv .venv
source .venv/bin/activate
python -m pip install -e './backend[dev]'
uvicorn app.main:app --app-dir backend --reload --host 0.0.0.0 --port 8000
```

Verify AWS authentication first:

```bash
aws sts get-caller-identity
```

## Tests

```bash
ruff check backend scripts
pytest -q backend/tests
```

## Terraform safety

Do not apply or destroy infrastructure blindly. Create a saved plan and inspect destructive actions first:

```bash
terraform plan -out=change.tfplan

terraform show -json change.tfplan | jq -r '
.resource_changes[]
| select(.change.actions | index("delete"))
| "\(.address) => \(.change.actions)"
'
```

For normal additive changes, the destructive check should produce no output.

The ECS ownership boundary is deliberate: Terraform owns infrastructure; GitHub CD owns promoted ECS task-definition revisions and immutable images. Terraform must not be used to roll back a CD-promoted application revision.

## Documentation

- [`docs/01-architecture.md`](docs/01-architecture.md) — production architecture
- [`ROADMAP.md`](ROADMAP.md) — public roadmap and contribution areas
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — contribution workflow
- [`SECURITY.md`](SECURITY.md) — security reporting and repository hygiene
- [`docs/02-roadmap.md`](docs/02-roadmap.md) — completed v1 roadmap and future expansion
- [`docs/10-stage-6-cicd-quality-gates.md`](docs/10-stage-6-cicd-quality-gates.md) — deployment quality gates
- [`docs/11-stage-7-sre-slo-runbook.md`](docs/11-stage-7-sre-slo-runbook.md) — SLOs and incident response
- [`docs/12-v1-production-validation.md`](docs/12-v1-production-validation.md) — final v1 validation record

## Engineering principle

A RAG change is not an improvement until it is measured against the versioned evaluation corpus and passes the release thresholds.
