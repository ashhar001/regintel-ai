# RegIntel AI v1 — Production Validation Record

This document records the production validation completed for the first portfolio-quality release of RegIntel AI.

## Release scope

RegIntel AI v1 is a production-oriented Amazon Bedrock RAG platform for financial/regulatory intelligence. The validated release includes:

- FastAPI application runtime on ECS Fargate
- Amazon Bedrock Knowledge Bases with Titan Text Embeddings V2
- OpenSearch Serverless vector retrieval
- semantic and hybrid retrieval with optional Cohere reranking
- grounded `RetrieveAndGenerate` answers with citations
- event-driven document ingestion
- Bedrock Guardrails
- private ECS networking through API Gateway VPC Link and an internal NLB
- Cognito authentication and AWS WAF
- GitHub Actions CI/CD with AWS OIDC
- immutable ECR image promotion
- RAG release-quality gates
- CloudWatch EMF application metrics
- request correlation
- SLOs, error budgets, burn-rate alerting, SNS routing
- API Gateway X-Ray tracing and incident diagnostics

## Production architecture validation

Validated request path:

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
ECS Fargate / FastAPI (private subnets, no public IP)
  |
  +--> Bedrock Knowledge Base / RetrieveAndGenerate
  |       |
  |       +--> OpenSearch Serverless vector index
  |       +--> Titan Text Embeddings V2
  |       +--> Cohere Rerank v3.5 when enabled
  |       +--> Amazon Nova Lite generation
  |
  +--> Bedrock Guardrails
```

Validated ingestion path:

```text
S3 incoming
  -> EventBridge
  -> SQS
  -> EventBridge Pipes
  -> Step Functions
  -> validation / hashing / idempotency / promotion
  -> Bedrock Knowledge Base ingestion job
  -> OpenSearch Serverless
```

## CI/CD validation

The deployment pipeline validates the candidate before promotion:

1. Python lint and unit tests
2. live candidate API startup against real Bedrock services
3. hard-corpus RAG regression
4. guardrail regression
5. immutable commit-SHA container build
6. ECR vulnerability gate with zero critical vulnerabilities allowed
7. ECS task-definition revision registration and deployment
8. ECS service stability check
9. public health check

Terraform PR plans are separately guarded against destructive changes.

The Stage 7D production deployment completed successfully through the full pipeline.

## RAG quality release gates

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

Representative validated evaluation results met the release thresholds. Reranking remains optional because baseline hybrid retrieval already passes the release contract.

## Guardrail validation

Unsafe-prompt regression is part of the release pipeline. Guardrail interventions are also emitted through the application metric `GuardrailBlockedCount`.

The application does not fabricate citations when a guardrail blocks a response.

## SRE validation

### Availability

- SLO: **99.9% successful RAG queries**
- Error budget: **0.1%**

Multi-window burn-rate alerting:

| Alert | Windows | Burn rate | Error-rate threshold |
| --- | --- | ---: | ---: |
| Fast burn | 5m AND 1h | 14.4x | 1.44% |
| Slow burn | 30m AND 6h | 6x | 0.60% |

The composite-alarm notification path was validated end to end:

```text
CloudWatch child burn alarms
  -> composite burn alarm
  -> encrypted SNS topic
  -> confirmed email notification
```

The test alarm state was restored to `OK` after validation.

### Latency

Operational objective:

- p95 RAG latency < 5 seconds

CloudWatch alarms and dashboards cover RAG latency, HTTP errors, request volume, retrieval latency, citation counts, guardrail interventions, ECS health and native Bedrock metrics.

## Trace and request correlation validation

A real public `/health` request validated API Gateway X-Ray propagation into the FastAPI runtime:

- HTTP status `200`
- application `x-request-id` returned
- API Gateway X-Ray `x-trace-id` returned
- the same request and trace IDs appeared in CloudWatch EMF and structured application logs

A production RAG query validated application-to-Bedrock request correlation:

- request ID: `stage7d-rag-e2e-001`
- HTTP status: `200`
- grounded answer: `Within two business days.`
- one citation returned
- RAG latency: `1565 ms`
- HTTP application latency: `1760 ms`
- the same request ID appeared in RAG EMF, Bedrock Knowledge Base success logs, HTTP EMF and HTTP completion logs

`aws apigateway test-invoke-method` does not traverse the deployed API Gateway stage in the same way as the public endpoint, so X-Ray trace injection is validated separately through the real public edge path.

## Terraform safety validation

Stage 7D final infrastructure plan:

```text
Plan: 4 to add, 1 to change, 0 to destroy.
Changed resources: 5
Allowed CD-owned replacements: 0
Destructive resources: 0
```

The single update was an in-place change enabling X-Ray tracing on the API Gateway stage. The four additions were the incident-diagnostics dashboard and three saved CloudWatch Logs Insights queries.

## Infrastructure ownership boundary

Terraform owns infrastructure resources. GitHub CD owns promoted ECS task-definition revisions and immutable application images.

Terraform must not roll ECS back to an older task definition promoted by CD. The ECS task definition and service lifecycle configuration preserve this ownership boundary.

Human notification destinations attached to the SRE SNS topic are operational configuration and are intentionally not hard-coded into this public repository. This avoids publishing personal endpoints while keeping the alerting topology under Terraform.

## Operational dashboards

Validated CloudWatch dashboards include:

- `regintel-dev-doziid-rag-operations`
- `regintel-dev-doziid-runtime`
- `regintel-dev-doziid-sre`
- `regintel-dev-doziid-slo`
- `regintel-dev-doziid-incident-diagnostics`

## Release status

**RegIntel AI v1 production platform: validated.**

The remaining roadmap items are product expansion rather than prerequisites for the v1 infrastructure/RAG platform release: analyst UI, agentic workflows, broader load/DR exercises, and portfolio/demo assets.
