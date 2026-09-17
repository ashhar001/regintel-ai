# Delivery Roadmap

## RegIntel AI v1 platform — complete ✅

The production RAG platform is validated end to end. The completed v1 scope is grouped below by capability rather than by the order in which the repository originally evolved.

## Foundation ✅

- product requirements and NFR contract
- FastAPI service foundation
- Amazon Bedrock integration
- Dockerized runtime
- configuration, logging and tests

## Core RAG infrastructure ✅

- Terraform-managed KMS, S3, IAM, OpenSearch Serverless
- Bedrock Knowledge Base and S3 data source
- Titan Text Embeddings V2
- retrieval-only and retrieve-and-generate API paths
- metadata filtering
- citations

## Production ingestion ✅

- EventBridge
- SQS + DLQ
- EventBridge Pipes
- Step Functions
- Lambda validation and promotion
- DynamoDB idempotency state
- Knowledge Base ingestion polling and status tracking

## Retrieval engineering and evaluation ✅

- semantic vs hybrid retrieval
- optional Cohere reranking
- versioned evaluation corpus
- Hit@K, MRR, answer coverage and citation accuracy
- release thresholds enforced in CI/CD
- frozen v1 default: HYBRID, top K = 5

## Security and production runtime ✅

- Cognito authentication
- AWS WAF
- API Gateway REST
- VPC Link
- internal Network Load Balancer
- ECS Fargate in private subnets
- no public IP on ECS tasks
- VPC endpoints for required AWS services
- Bedrock Guardrails
- least-privilege runtime IAM

## CI/CD ✅

- GitHub Actions
- AWS OIDC federation
- Terraform remote state
- destructive-plan gate
- immutable commit-SHA ECR images
- vulnerability gate
- RAG regression gate
- guardrail regression gate
- ECS service stability validation
- public health check

## Observability and SRE ✅

- CloudWatch EMF application metrics
- structured JSON logs
- request correlation
- API Gateway X-Ray tracing
- 99.9% RAG availability SLO
- 0.1% error budget
- p95 RAG latency objective < 5 seconds
- fast and slow burn-rate alerts
- composite alarm routing through SNS
- SRE, SLO and incident-diagnostics dashboards
- saved CloudWatch Logs Insights queries
- incident runbook

## Production validation ✅

The v1 release has validated:

- full CI/CD deployment
- Terraform plan safety with zero destructive resources for Stage 7D
- public X-Ray trace propagation
- request/trace correlation in CloudWatch
- production RAG request correlation through the Bedrock Knowledge Base path
- grounded answer and citation behavior
- SLO alarm routing

See [`12-v1-production-validation.md`](12-v1-production-validation.md).

---

# Future product expansion

These are valuable next phases, but they are not prerequisites for calling the v1 RAG platform production-ready.

## Analyst UI

- authenticated analyst interface
- streaming responses
- citation/source viewer
- feedback capture
- query history

## Agentic workflows

- policy/document comparison
- evidence-backed action plans
- controlled tool use
- explicit human approval for consequential actions

## Scale and resilience exercises

- structured load testing
- quota and throttling tests
- larger-corpus retrieval benchmarks
- backup/recovery exercises
- regional recovery design
- cost/performance tuning under sustained traffic

## Portfolio release assets

- polished architecture diagram
- benchmark summary
- short demo video
- LinkedIn technical case study
- interview-ready architecture narrative

## Guiding principle

Future functionality should preserve the same production contract: measurable quality, secure-by-default infrastructure, safe Terraform changes, observable behavior, and automated release gates.
