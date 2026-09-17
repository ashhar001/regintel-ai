# Production Architecture

## Request path

```text
Client
  -> AWS WAF
  -> API Gateway REST API
  -> Cognito authorization
  -> API Gateway X-Ray tracing
  -> VPC Link
  -> internal Network Load Balancer
  -> ECS Fargate / FastAPI in private subnets
  -> Amazon Bedrock Knowledge Base
  -> OpenSearch Serverless vector retrieval
  -> optional Cohere reranking
  -> Amazon Nova Lite grounded generation
  -> Bedrock Guardrails
  -> cited response
```

The ECS service runs without public IPs. Private AWS service access is provided through VPC endpoints for Bedrock runtime / agent runtime, ECR, CloudWatch Logs and S3.

## Retrieval path

```text
FastAPI
  -> Bedrock Knowledge Base
  -> metadata filters + HYBRID or SEMANTIC retrieval
  -> OpenSearch Serverless FAISS vector index
  -> optional Cohere Rerank v3.5
  -> RetrieveAndGenerate with Amazon Nova Lite
  -> answer + citations
```

The frozen v1 default is `HYBRID` with top K = 5. Reranking remains optional and is release-gated through the evaluation corpus.

## Ingestion path

```text
S3 incoming
  -> EventBridge
  -> SQS + DLQ
  -> EventBridge Pipes
  -> Step Functions
  -> Lambda validation / hashing / fingerprinting
  -> DynamoDB idempotency state
  -> promotion to canonical S3 document path + metadata
  -> Bedrock Knowledge Base ingestion job
  -> Titan Text Embeddings V2
  -> OpenSearch Serverless
```

The ingestion workflow supports production-oriented validation, status tracking, idempotency and failure routing.

## CI/CD path

```text
GitHub push to main
  -> GitHub Actions
  -> AWS OIDC role assumption
  -> lint + unit tests
  -> live Bedrock candidate API
  -> hard-corpus RAG regression
  -> guardrail regression
  -> immutable commit-SHA Docker image
  -> ECR vulnerability gate
  -> ECS task-definition revision
  -> ECS stable-service check
  -> public health check
```

Terraform PR workflows run a separate infrastructure plan and block destructive resource actions outside the explicitly allowed CD ownership boundary.

## Evaluation path

```text
Versioned evaluation corpus
  -> retrieval / RAG matrix
  -> Hit@K / MRR / answer coverage / citation accuracy / latency
  -> release thresholds
  -> deployment gate
```

Current release contract:

- Hit@K = 1.00
- MRR >= 0.70
- answer coverage >= 0.95
- citation document accuracy >= 0.875

## Observability and SRE

```text
API Gateway X-Ray
      |
      v
trace_id + request_id
      |
FastAPI structured logs + CloudWatch EMF
      |
      +--> RAG / HTTP / retrieval signals
      +--> native Bedrock metrics
      +--> SRE dashboard
      +--> SLO dashboard
      +--> incident-diagnostics dashboard
      +--> CloudWatch alarms
      +--> multi-window burn-rate composites
      +--> encrypted SNS alert topic
```

Application metric dimensions are intentionally low-cardinality: `Service`, `Environment`, and `Operation`. `request_id` and `trace_id` are log/EMF properties rather than metric dimensions.

## Service objectives

- availability SLO: 99.9% successful RAG queries
- error budget: 0.1%
- RAG latency objective: p95 < 5 seconds

Availability burn alerting uses 5m + 1h fast-burn windows and 30m + 6h slow-burn windows.

## Ownership boundary

Terraform owns infrastructure resources. GitHub CD owns promoted ECS task-definition revisions and immutable images.

Terraform lifecycle configuration deliberately ignores the CD-owned task-definition revision so infrastructure reconciliation cannot roll the application back to an older image.

## Security model

- Cognito protects `/v1/*` production API methods.
- AWS WAF protects the API Gateway stage.
- ECS tasks have no public IP.
- runtime IAM is least privilege for Bedrock, reranking, guardrails and KMS decrypt where required.
- Guardrails are regression-tested before deployment.
- prompts and retrieved regulatory content are not added as X-Ray trace attributes.
